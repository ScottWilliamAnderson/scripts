# Defines the Start-Opencode function. Dot-source this file (e.g. from your
# PowerShell profile) to make Start-Opencode available, or run it directly:
#   . .\Start-Opencode.ps1; Start-Opencode liftosaur

function Start-Opencode {
    <#
    .SYNOPSIS
        One-command launcher for opencode running inside a NVIDIA OpenShell sandbox in WSL.
    .DESCRIPTION
        Spins up (or resumes) a per-project OpenShell sandbox in WSL, starts `opencode web`
        inside it, port-forwards it to the Windows host, optionally allows a local
        llama.cpp server to be reached from the sandbox, then opens the web UI in a
        browser. Designed for: open laptop -> `Start-Opencode <repo>` -> code.

        Phone access works for free via Tailscale MagicDNS at http://g14-wsl:<Port>
        (assuming "Use Tailscale DNS" is enabled on the phone).

        The opencode web password is stored DPAPI-encrypted under
        %LOCALAPPDATA%\StartOpencode\ (user-account-bound, like Windows Credential Manager).
    .PARAMETER Project
        Name of the project folder under SrcRoot (default C:\Users\<you>\src).
        Used as both the source dir and the sandbox name.
    .PARAMETER Port
        Local port to forward the opencode web UI on. Default 4096.
    .PARAMETER Llama
        Open a network hole to a local llama-server running on the Windows host
        (reached via the Windows Tailscale IP). Pair with `llama-server --host 0.0.0.0`.
    .PARAMETER LlamaPort
        Port the local llama-server listens on. Default 8081.
    .PARAMETER NoBrowser
        Skip auto-opening the browser to the web UI.
    .PARAMETER Recreate
        Delete the existing sandbox of this name and create a fresh one (re-upload).
    .PARAMETER RotatePassword
        Force a fresh prompt for the opencode web password, recreate the openshell
        provider, attach it, and restart opencode web so the new password takes
        effect immediately. Use this if you ever need to change the web password.
    .PARAMETER SrcRoot
        Root directory for projects. Default $env:USERPROFILE\src.
    .PARAMETER Distro
        WSL distro that has OpenShell installed. Default Ubuntu-24.04.
    .EXAMPLE
        Start-Opencode liftosaur
        # Resume or create the 'liftosaur' sandbox, start opencode web on :4096, open browser.
    .EXAMPLE
        Start-Opencode myrepo -Llama
        # Same, plus allow the sandbox to reach the local llama-server on the Windows host.
    .EXAMPLE
        Start-Opencode liftosaur -Recreate -NoBrowser
        # Nuke and recreate the sandbox (re-uploads files), don't open a browser.
    .NOTES
        File Name      : Start-Opencode.ps1
        Prerequisite   : WSL with Ubuntu-24.04 (glibc >= 2.38), OpenShell installed in WSL,
                         Tailscale installed on Windows and inside WSL.
        Copyright      : Scott Anderson 2026
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0,
            HelpMessage = "Project folder name under SrcRoot (also the sandbox name)")]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]$Project,

        [Parameter()]
        [ValidateRange(1024, 65535)]
        [int]$Port = 4096,

        [Parameter()]
        [switch]$Llama,

        [Parameter()]
        [ValidateRange(1024, 65535)]
        [int]$LlamaPort = 8081,

        [Parameter()]
        [switch]$NoBrowser,

        [Parameter()]
        [switch]$Recreate,

        [Parameter()]
        [switch]$RotatePassword,

        [Parameter()]
        [string]$SrcRoot = (Join-Path $env:USERPROFILE 'src'),

        [Parameter()]
        [string]$Distro = 'Ubuntu-24.04'
    )

    # --- Local helpers (scoped to this function) --------------------------

    function Write-Step {
        param([string]$Message)
        Write-Host ""
        Write-Host "==> $Message" -ForegroundColor Cyan
    }

    function Invoke-Wsl {
        <#
        .SYNOPSIS
            Runs a bash one-liner in the target WSL distro and returns stdout+stderr
            joined into a SINGLE string, with WSL launcher noise filtered out.
        .DESCRIPTION
            Returning a string (not an array) matters because PowerShell's `-match` /
            `-notmatch` operators behave differently on arrays (they filter
            element-wise instead of matching the whole blob).

            The WSL relay process emits launcher diagnostics on stderr (e.g.
            "getpwuid(1000) failed 0") before bash even starts. We can't tell that
            apart from real errors at the PS stream level, so we filter the well-
            known noise patterns out by line.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)][string]$Command
        )
        $raw = wsl -d $Distro -- bash -lc $Command 2>&1
        $clean = $raw | Where-Object {
            $_ -notmatch '^\s*<\d>WSL' -and
            $_ -notmatch 'getpwuid\(\d+\) failed'
        }
        return (($clean | ForEach-Object { $_.ToString() }) -join "`n")
    }

    function ConvertTo-WslPath {
        param([string]$WindowsPath)
        $drive = $WindowsPath.Substring(0, 1).ToLower()
        $rest = $WindowsPath.Substring(2) -replace '\\', '/'
        return "/mnt/$drive$rest"
    }

    function Get-OpencodeWebPassword {
        $dir = Join-Path $env:LOCALAPPDATA 'StartOpencode'
        $file = Join-Path $dir 'opencode_web.cred'

        if (-not (Test-Path $file)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "First-time setup: choose a password for the opencode web UI." -ForegroundColor Yellow
            Write-Host "It will be saved DPAPI-encrypted (only your Windows account can decrypt)." -ForegroundColor DarkGray
            $sec = Read-Host "OpenCode web password" -AsSecureString
            $sec | ConvertFrom-SecureString | Set-Content -Path $file -Encoding ASCII
            Write-Host "Saved to $file" -ForegroundColor Green
        }

        $sec = Get-Content $file | ConvertTo-SecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try {
            return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    function Test-TailscaleWindows {
        $ip = (& tailscale ip -4 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -ne 0 -or -not $ip) { return $null }
        return $ip.Trim()
    }

    function Get-WslTailscale {
        <#
        .SYNOPSIS
            Returns @{ Ip; HostName } for the WSL distro's Tailscale identity,
            or @{ Ip = $null; HostName = $null } if Tailscale isn't up in WSL.
            HostName is the MagicDNS short name (column 2 of `tailscale status`).
        .NOTES
            We deliberately avoid awk `$2`-style extraction because the dollar sign
            gets eaten by bash positional-arg expansion through the PS→wsl→bash
            layers. `tr -s ' '` collapses runs of spaces; `cut -d' ' -f2` then
            grabs field 2 — no dollar signs anywhere.
        #>
        $ip = Invoke-Wsl 'tailscale ip -4 2>/dev/null | head -1'
        $name = Invoke-Wsl 'tailscale status --self=true --peers=false 2>/dev/null | head -1 | tr -s " " | cut -d" " -f2'
        return @{
            Ip       = if ($ip) { $ip.Trim() } else { $null }
            HostName = if ($name) { $name.Trim() } else { $null }
        }
    }

    function Wait-Port {
        param(
            [int]$Port,
            [int]$TimeoutSec = 20
        )
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            try {
                $c = New-Object System.Net.Sockets.TcpClient
                $iar = $c.BeginConnect('127.0.0.1', $Port, $null, $null)
                if ($iar.AsyncWaitHandle.WaitOne(500) -and $c.Connected) {
                    $c.EndConnect($iar)
                    $c.Close()
                    return $true
                }
                $c.Close()
            }
            catch { Start-Sleep -Milliseconds 300 }
        }
        return $false
    }

    # --- Main flow --------------------------------------------------------

    try {
        $projectPath = Join-Path $SrcRoot $Project
        if (-not (Test-Path $projectPath -PathType Container)) {
            throw "Project directory not found: $projectPath"
        }
        $wslProjectPath = ConvertTo-WslPath $projectPath

        Write-Step "Checking Tailscale on Windows"
        $winTsIp = Test-TailscaleWindows
        if (-not $winTsIp) {
            if ($Llama) {
                Write-Warning "Tailscale on Windows isn't connected. -Llama needs it to reach the local llama-server. Run 'tailscale up' on Windows."
            }
            else {
                Write-Host "Tailscale on Windows not connected (only matters for -Llama; phone access uses WSL's Tailscale)." -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "Windows tailnet IP: $winTsIp"
        }

        Write-Step "Ensuring WSL ($Distro) is running"
        $null = Invoke-Wsl 'true'

        Write-Step "Checking OpenShell gateway"
        $gw = Invoke-Wsl 'openshell status 2>&1'
        if ($gw -notmatch 'Connected') {
            Write-Warning "OpenShell gateway not Connected. Output was:`n$gw"
            Write-Warning "Try: wsl -- sudo systemctl --user -M root@ restart openshell-gateway"
            throw "Gateway not reachable; aborting."
        }

        # Tracks whether the opencode_web provider (and therefore the password env)
        # changed during this run. If yes, any running opencode-web process needs
        # killing so a fresh exec picks up the new env.
        $providerChanged = $false

        if ($RotatePassword) {
            Write-Step "Rotating opencode web password"
            $credFile = Join-Path (Join-Path $env:LOCALAPPDATA 'StartOpencode') 'opencode_web.cred'
            if (Test-Path $credFile) { Remove-Item $credFile -Force }
            Invoke-Wsl 'openshell provider delete opencode_web 2>&1' | Out-Null
            $providerChanged = $true
        }

        Write-Step "Ensuring opencode_web provider exists"
        $hasProvider = Invoke-Wsl "openshell provider get opencode_web 2>&1 | grep -i 'opencode_web' | head -1"
        if (-not $hasProvider) {
            $pw = Get-OpencodeWebPassword
            $env:OPENCODE_SERVER_PASSWORD = $pw
            $prevWslEnv = $env:WSLENV
            $env:WSLENV = if ($prevWslEnv) { "$prevWslEnv`:OPENCODE_SERVER_PASSWORD/u" } else { "OPENCODE_SERVER_PASSWORD/u" }
            try {
                $create = Invoke-Wsl 'openshell provider create --name opencode_web --type generic --credential OPENCODE_SERVER_PASSWORD'
                Write-Host $create
                $providerChanged = $true
            }
            finally {
                Remove-Item Env:\OPENCODE_SERVER_PASSWORD -ErrorAction SilentlyContinue
                if ($prevWslEnv) { $env:WSLENV = $prevWslEnv } else { Remove-Item Env:\WSLENV -ErrorAction SilentlyContinue }
            }
        }
        else {
            Write-Host "Provider already configured."
        }

        if ($Recreate) {
            Write-Step "Recreate: deleting existing sandbox '$Project'"
            Invoke-Wsl "openshell sandbox delete $Project 2>&1" | Out-Host
        }

        # Detect sandbox by line that starts with the name and a space; awk-$1 avoided
        # for the same dollar-expansion reason as Get-WslTailscale.
        $hasSandbox = Invoke-Wsl "openshell sandbox list 2>&1 | grep -E '^$Project[[:space:]]'"
        if (-not $hasSandbox) {
            Write-Step "Creating sandbox '$Project' (uploading $projectPath -> sandbox ~)"
            $createCmd = "openshell sandbox create --name $Project --provider openrouter --provider opencode_web --upload '$wslProjectPath' -- true"
            $r = Invoke-Wsl $createCmd
            Write-Host $r
            $providerChanged = $true   # fresh sandbox, opencode-web hasn't started yet
        }
        else {
            Write-Host "Sandbox '$Project' already exists."
            # Sandbox pre-existed — make sure both providers are attached. attach
            # is idempotent: re-attaching an attached provider is a no-op.
            $attached = Invoke-Wsl "openshell sandbox provider list $Project 2>&1"
            foreach ($provName in @('openrouter', 'opencode_web')) {
                if ($attached -notmatch "(^|\s)$provName(\s|$)") {
                    Write-Host "Attaching provider '$provName' to existing sandbox..."
                    Invoke-Wsl "openshell sandbox provider attach $Project $provName" | Out-Host
                    $providerChanged = $true
                }
            }
        }

        Write-Step "Applying opencode network policy"
        $binFlags = "--binary /usr/local/bin/opencode --binary /usr/bin/node --binary /usr/lib/node_modules/opencode-ai/bin/.opencode"
        $polCmd = "openshell policy update $Project --add-endpoint app.opencode.ai:443 --add-endpoint api.opencode.ai:443 $binFlags --wait"
        Invoke-Wsl $polCmd | Out-Host

        if ($Llama) {
            Write-Step "Allowing local llama-server at ${winTsIp}:$LlamaPort"
            if (-not $winTsIp) {
                Write-Warning "-Llama needs Tailscale on Windows to be up so the sandbox knows where to reach you. Skipping policy add."
            }
            else {
                $llamaCmd = "openshell policy update $Project --add-endpoint ${winTsIp}:$LlamaPort $binFlags --wait"
                Invoke-Wsl $llamaCmd | Out-Host
                Write-Host ""
                Write-Host "Point opencode at the local model with base URL:" -ForegroundColor Yellow
                Write-Host "  http://${winTsIp}:$LlamaPort/v1" -ForegroundColor Yellow
            }
        }

        Write-Step "Starting opencode web inside sandbox"
        $running = Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'pgrep -f \""opencode web\"" >/dev/null && echo YES || echo NO'"
        $shouldRestart = $providerChanged -and ($running -match 'YES')
        if ($shouldRestart) {
            Write-Host "Provider/password changed; restarting opencode web to pick up new env..."
            Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'pkill -f \""opencode web\""; sleep 1'" | Out-Null
            $running = 'NO'
        }
        if ($running -notmatch 'YES') {
            Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'nohup opencode web --port $Port >/tmp/opencode-web.log 2>&1 & disown; sleep 1; echo started'" | Out-Host
        }
        else {
            Write-Host "opencode web already running in sandbox."
        }

        Write-Step "Ensuring port forward localhost:$Port -> sandbox:$Port"
        $fwd = Invoke-Wsl "openshell forward list 2>&1"
        if ($fwd -notmatch "$Port.*$Project") {
            Invoke-Wsl "openshell forward start 0.0.0.0:$Port $Project -d" | Out-Host
        }
        else {
            Write-Host "Forward already running."
        }

        Write-Step "Waiting for $Port to accept connections"
        if (-not (Wait-Port -Port $Port -TimeoutSec 20)) {
            Write-Warning "Port $Port not responding yet. Check: wsl openshell sandbox exec -n $Project --no-tty -- cat /tmp/opencode-web.log"
        }

        $url = "http://localhost:$Port"
        $wslTs = Get-WslTailscale
        Write-Host ""
        Write-Host "OpenCode is ready." -ForegroundColor Green
        Write-Host "  Windows : $url" -ForegroundColor Cyan
        if ($wslTs.HostName) {
            Write-Host "  Phone   : http://$($wslTs.HostName):$Port  (MagicDNS)" -ForegroundColor Cyan
        }
        if ($wslTs.Ip) {
            Write-Host "  Phone   : http://$($wslTs.Ip):$Port  (Tailscale IP fallback if MagicDNS fails)" -ForegroundColor Cyan
        }
        if (-not $wslTs.HostName -and -not $wslTs.Ip) {
            Write-Host "  Phone   : (Tailscale isn't up in WSL; run 'wsl -- sudo tailscale up' to enable remote access)" -ForegroundColor Yellow
        }
        Write-Host "  Login   : opencode / <your saved password>"
        Write-Host ""
        Write-Host "  Project : $projectPath"   -ForegroundColor DarkGray
        Write-Host "  Sandbox : $Project"       -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Useful follow-ups:"
        Write-Host "  Logs:     wsl openshell sandbox exec -n $Project --no-tty -- tail -f /tmp/opencode-web.log"
        Write-Host "  Stop:     wsl openshell sandbox exec -n $Project --no-tty -- pkill -f 'opencode web'"
        Write-Host "  Unfwd:    wsl openshell forward stop $Port $Project"
        Write-Host "  Recreate: Start-Opencode $Project -Recreate"

        if (-not $NoBrowser) {
            Start-Process $url
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
