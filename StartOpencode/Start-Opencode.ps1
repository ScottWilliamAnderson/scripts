# Defines the Start-Opencode function. Dot-source this file (e.g. from your
# PowerShell profile) to make Start-Opencode available, or run it directly:
#   . .\Start-Opencode.ps1; Start-Opencode liftosaur

function global:Start-Opencode {
    <#
    .SYNOPSIS
        One-command launcher for opencode running inside a NVIDIA OpenShell sandbox in WSL.
    .DESCRIPTION
        Spins up (or resumes) a per-project OpenShell sandbox in WSL, starts `opencode web`
        inside it, port-forwards it to the Windows host, optionally allows a local
        llama.cpp server to be reached from the sandbox, then opens the web UI in a
        browser. Designed for: open laptop -> `Start-Opencode <repo>` -> code.

        Phone access works for free via Tailscale MagicDNS at http://<your-wsl>:<Port>
        (assuming "Use Tailscale DNS" is enabled on the phone).

        The opencode web password is stored DPAPI-encrypted under
        %LOCALAPPDATA%\StartOpencode\ (user-account-bound, like Windows Credential Manager).
        It is delivered into the sandbox by piping it via stdin into a 0600 file
        at /sandbox/.opencode_web_env, which is then sourced when opencode-web
        starts. We deliberately do NOT use an OpenShell provider for this value:
        provider credentials are opaque placeholder tokens that the egress proxy
        substitutes only in outbound HTTP requests, so they break local-auth
        use cases like the opencode-web login.
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
        [switch]$NoRipgrep,

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
            joined into a SINGLE string, with WSL launcher noise and ANSI escape
            sequences stripped.
        .DESCRIPTION
            Returning a string (not an array) matters because PowerShell's `-match` /
            `-notmatch` operators behave differently on arrays (they filter
            element-wise instead of matching the whole blob).

            The WSL relay process emits launcher diagnostics on stderr (e.g.
            "getpwuid(1000) failed 0") before bash even starts. We can't tell that
            apart from real errors at the PS stream level, so we filter the well-
            known noise patterns out by line.

            We also strip ANSI escape sequences (e.g. ESC[2m...ESC[0m around field
            labels in `openshell` output), because they break naive regex parsing —
            e.g. `Phase:\s*(\S+)` will capture the trailing ESC[0m instead of the
            actual value.
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
        $joined = ($clean | ForEach-Object { $_.ToString() }) -join "`n"
        return $joined -replace '\x1b\[[0-9;]*[A-Za-z]', ''
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

    function Set-SandboxWebPassword {
        <#
        .SYNOPSIS
            Writes the opencode-web env file (/sandbox/.opencode_web_env, mode
            0600) containing both OPENCODE_SERVER_PASSWORD and a curated PATH
            that includes /sandbox/.local/bin (so ripgrep is found).
        .NOTES
            We use a Windows tempfile (written with explicit UTF-8 + LF, no BOM)
            and `cat` it into the wsl pipeline rather than `$str | wsl ...`,
            because PowerShell's native-process pipe converts the trailing
            newline to CRLF on Windows, which would leave a stray \r in the
            password value. The tempfile lives briefly under %TEMP% (user-only
            ACL) and is deleted in a finally block.

            PATH lives in the env file (not on the launch command line) because
            attempting to expand `$PATH` through PS->wsl->openshell-exec layers
            kept getting the WSL host's $PATH expanded prematurely by the outer
            bash, polluting opencode's PATH with Windows paths containing
            parentheses that broke the inner shell parser. Putting PATH in the
            env file dodges every layer of quoting.

            Throws if the underlying wsl/openshell call fails so the caller can
            short-circuit instead of pretending it succeeded.
        #>
        param(
            [Parameter(Mandatory)][string]$Sandbox,
            [Parameter(Mandatory)][string]$Password
        )
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            $sandboxPath = '/sandbox/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            $content = "OPENCODE_SERVER_PASSWORD=$Password`nPATH=$sandboxPath`n"
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($content)
            [System.IO.File]::WriteAllBytes($tmp, $bytes)
            $wslTmp = ConvertTo-WslPath $tmp
            $cmd = "cat '$wslTmp' | openshell sandbox exec -n $Sandbox --no-tty -- bash -c 'umask 077 && cat > /sandbox/.opencode_web_env && chmod 600 /sandbox/.opencode_web_env'"
            $output = wsl -d $Distro -- bash -lc $cmd 2>&1
            if ($LASTEXITCODE -ne 0) {
                $clean = $output | Where-Object {
                    $_ -notmatch '^\s*<\d>WSL' -and $_ -notmatch 'getpwuid\(\d+\) failed'
                }
                throw "writing /sandbox/.opencode_web_env failed: $(($clean | ForEach-Object { $_.ToString() }) -join ' ')"
            }
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
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

    function Wait-SandboxReady {
        <#
        .SYNOPSIS
            Polls `openshell sandbox get <name>` until Phase is Ready.
            Throws on timeout (with a hint to recreate, since a genuinely
            wedged MicroVM is the other common cause). MicroVM provisioning
            on a cold start can take 60-150s on a busy machine, so the
            default is set generously.
        #>
        param(
            [Parameter(Mandatory)][string]$Sandbox,
            [int]$TimeoutSec = 300
        )
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        $lastPhase = '(unknown)'
        while ((Get-Date) -lt $deadline) {
            $info = Invoke-Wsl "openshell sandbox get $Sandbox 2>&1"
            if ($info -match 'Phase:\s*(\S+)') { $lastPhase = $matches[1] }
            if ($lastPhase -eq 'Ready') { return }
            Start-Sleep -Milliseconds 500
        }
        throw "Sandbox '$Sandbox' stuck in phase '$lastPhase' after ${TimeoutSec}s. If it's been Provisioning the whole time, the MicroVM is likely wedged — try: Start-Opencode $Sandbox -Recreate"
    }

    function Get-PortListener {
        <#
        .SYNOPSIS
            Returns $true if anything is listening on the given TCP port inside WSL.
            We use `ss` because the on-the-host listener is what matters for the
            Windows-side localhost mirror, not what `openshell forward list` reports.
        #>
        param([int]$Port)
        $busy = Invoke-Wsl "ss -tlnH 2>/dev/null | awk '{print `$4}' | grep -E ':${Port}`$' | head -1"
        return -not [string]::IsNullOrWhiteSpace($busy)
    }

    function Get-ForwardUnit {
        # Stable systemd-user unit name for "this project's forward on this port".
        param([string]$Project, [int]$Port)
        return "opencode-fwd-$Project-$Port"
    }

    function Install-RipgrepInSandbox {
        <#
        .SYNOPSIS
            Ensures /sandbox/.local/bin/rg is present in the sandbox. Returns
            $true if rg is available afterwards. opencode-web needs ripgrep for
            its glob/grep/codesearch/skill tools; the base sandbox image ships
            without it and the sandbox user can't apt-install (read-only /usr).
        .NOTES
            Cached on the Windows side at %LOCALAPPDATA%\StartOpencode\cache\rg-<ver>
            so the GitHub download happens at most once per machine.
        #>
        param([string]$Project)
        $check = Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'test -x /sandbox/.local/bin/rg && echo yes || echo no'"
        if ($check -match 'yes') { return $true }

        $rgVer = '14.1.1'
        $cacheDir = Join-Path $env:LOCALAPPDATA 'StartOpencode\cache'
        $rgPath   = Join-Path $cacheDir "rg-$rgVer"
        if (-not (Test-Path $rgPath)) {
            Write-Host "Downloading ripgrep $rgVer (one-time, cached at $rgPath)..." -ForegroundColor DarkGray
            New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
            $tar = Join-Path $cacheDir "rg-$rgVer.tar.gz"
            $url = "https://github.com/BurntSushi/ripgrep/releases/download/$rgVer/ripgrep-$rgVer-x86_64-unknown-linux-musl.tar.gz"
            try {
                Invoke-WebRequest -Uri $url -OutFile $tar -UseBasicParsing
            }
            catch {
                Write-Warning "Couldn't download ripgrep ($($_.Exception.Message)). opencode's grep/glob tools won't work."
                return $false
            }
            $extract = Join-Path $cacheDir "extract"
            if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
            New-Item -ItemType Directory -Force -Path $extract | Out-Null
            tar -xzf $tar -C $extract
            $found = Get-ChildItem -Recurse -File -Filter rg -Path $extract | Select-Object -First 1
            if (-not $found) {
                Write-Warning "Extracted ripgrep archive but rg binary not found inside it."
                return $false
            }
            Copy-Item -Path $found.FullName -Destination $rgPath
            Remove-Item -Recurse -Force $extract
            Remove-Item -Force $tar
        }

        # Heal a previous botched install if needed: `openshell sandbox upload`
        # treats DEST as the literal destination *path*, not "a directory to
        # put the file in" — so an earlier `upload rg /sandbox/.local/bin`
        # would have written the binary AS /sandbox/.local/bin (clobbering it
        # into a 6.5 MB file). Make sure /sandbox/.local/bin is actually a dir
        # before uploading.
        Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'test -f /sandbox/.local/bin && rm -f /sandbox/.local/bin; mkdir -p /sandbox/.local/bin'" | Out-Null

        # Upload to the explicit destination path (binary becomes rg, not a
        # dir nested inside).
        $wslRg = ConvertTo-WslPath $rgPath
        Invoke-Wsl "openshell sandbox upload $Project '$wslRg' /sandbox/.local/bin/rg" | Out-Null
        Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- chmod +x /sandbox/.local/bin/rg" | Out-Null
        return $true
    }

    function Test-ForwardUnit {
        # Is the named systemd-user unit currently active?
        param([string]$Unit)
        $state = Invoke-Wsl "systemctl --user is-active $Unit 2>/dev/null"
        return ($state.Trim() -eq 'active')
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

        Write-Step "Checking that port $Port isn't owned by a different sandbox"
        # Conflict only if the port is listening AND it's not the forward unit for
        # *this* project. Other projects' forward units listening on $Port would
        # be holding the port; we ask the user to stop them first.
        if (Get-PortListener -Port $Port) {
            $myUnit = Get-ForwardUnit -Project $Project -Port $Port
            $isMine = Test-ForwardUnit -Unit $myUnit
            if (-not $isMine) {
                # Find any other opencode-fwd unit that might own the port.
                $allUnits = Invoke-Wsl "systemctl --user list-units --type=service --no-legend --plain 2>/dev/null | awk '/opencode-fwd-/{print `$1}'"
                $other = ($allUnits -split "`n" | Where-Object { $_ -match "opencode-fwd-.+-$Port\.service" } | Select-Object -First 1)
                if ($other) {
                    $otherProject = ($other -replace '^opencode-fwd-', '' -replace "-$Port\.service.*$", '')
                    throw "Port $Port is busy (in use by another Opencode sandbox '$otherProject'). Use -Port <other> for this project, or stop the other with: Stop-Opencode $otherProject"
                }
                throw "Port $Port is busy (something else is listening). Use -Port <other>, or stop whatever is on $Port first."
            }
        }

        Write-Step "Checking OpenShell gateway"
        # Brief retry: if the gateway is configured for the docker driver and
        # Docker Desktop has just been started, the gateway service may still
        # be in the middle of a restart cycle (Restart=on-failure, 5s backoff).
        $gw = $null
        for ($i = 0; $i -lt 4; $i++) {
            $gw = Invoke-Wsl 'openshell status 2>&1'
            if ($gw -match 'Connected') { break }
            if ($i -eq 0) { Write-Host "  Gateway not yet Connected; retrying for ~15s..." -ForegroundColor DarkGray }
            Start-Sleep -Seconds 5
        }
        if ($gw -notmatch 'Connected') {
            # Detect whether the gateway is configured for docker driver and
            # docker is unreachable — that's the most common "gateway down"
            # cause once you've migrated to scott + docker.
            $driver = Invoke-Wsl 'grep -h OPENSHELL_DRIVERS ~/.config/openshell/gateway.env 2>/dev/null | cut -d= -f2'
            $dockerOk = $false
            if ($driver -match 'docker') {
                $dockerOk = (Invoke-Wsl 'docker info >/dev/null 2>&1 && echo OK') -match 'OK'
            }

            Write-Warning "OpenShell gateway not Connected. Output was:`n$gw"
            Write-Warning ""
            if ($driver -match 'docker' -and -not $dockerOk) {
                Write-Warning "The gateway is configured to use Docker (OPENSHELL_DRIVERS=docker),"
                Write-Warning "but the Docker daemon isn't reachable. **Start Docker Desktop on Windows**"
                Write-Warning "and wait ~5s — the gateway will auto-recover (it restarts on-failure)."
                Write-Warning "Then re-run: Start-Opencode $Project"
            }
            else {
                Write-Warning "If you've never run setup, or the gateway has become wedged, run:"
                Write-Warning "    Initialize-Opencode"
                Write-Warning ""
                Write-Warning "That sets up the gateway under your user with lingering enabled so"
                Write-Warning "it auto-starts at every WSL boot. It's idempotent — safe to re-run."
            }
            throw "Gateway not reachable; aborting."
        }

        # Tracks whether the password reached the sandbox this run. If yes,
        # the running opencode-web process (if any) must be killed and restarted
        # so a fresh exec re-sources the .opencode_web_env file.
        $passwordChanged = $false

        if ($RotatePassword) {
            Write-Step "Rotating opencode web password"
            $credFile = Join-Path (Join-Path $env:LOCALAPPDATA 'StartOpencode') 'opencode_web.cred'
            if (Test-Path $credFile) { Remove-Item $credFile -Force }
            $passwordChanged = $true
        }

        # Clean up the legacy opencode_web provider if it exists. Earlier versions
        # of this script created it; we no longer use it because provider env vars
        # are opaque placeholder tokens (the egress proxy substitutes them only in
        # outbound HTTP), which broke opencode-web's local auth check.
        $legacyProvider = Invoke-Wsl "openshell provider get opencode_web 2>&1 | grep -i 'opencode_web' | head -1"
        if ($legacyProvider) {
            Write-Host "Removing legacy opencode_web provider (no longer used)..." -ForegroundColor DarkGray
            Invoke-Wsl 'openshell provider delete opencode_web 2>&1' | Out-Null
            $passwordChanged = $true   # running opencode-web may have stale env from old provider
        }

        if ($Recreate) {
            Write-Step "Recreate: deleting existing sandbox '$Project'"
            Invoke-Wsl "openshell sandbox delete $Project 2>&1" | Out-Host
            # `delete` returns immediately but the sandbox stays listed in
            # `Deleting` phase for a few seconds while the container is torn
            # down. If we proceed too fast, the "does the sandbox exist?"
            # check below sees the Deleting entry, skips create, and then
            # Wait-SandboxReady spins forever waiting for a corpse to be Ready.
            Write-Host "Waiting for delete to complete..." -ForegroundColor DarkGray
            $deadline = (Get-Date).AddSeconds(60)
            while ((Get-Date) -lt $deadline) {
                $still = Invoke-Wsl "openshell sandbox list 2>&1 | grep -E '^$Project[[:space:]]'"
                if ([string]::IsNullOrWhiteSpace($still)) { break }
                Start-Sleep -Milliseconds 500
            }
        }

        # Detect sandbox by line that starts with the name and a space; awk-$1 avoided
        # for the same dollar-expansion reason as Get-WslTailscale.
        $hasSandbox = Invoke-Wsl "openshell sandbox list 2>&1 | grep -E '^$Project[[:space:]]'"
        $needsUpload = $false
        if (-not $hasSandbox) {
            Write-Step "Creating sandbox '$Project' (this can take 60-90s on first run while it pulls the image)"
            # NOTE: we deliberately do NOT pass --upload here. `openshell sandbox
            # create --upload` has a race where it starts uploading before the
            # VM supervisor is ready and fails with "sandbox is not ready",
            # leaving the sandbox in Provisioning with no files. Upload as a
            # separate step after Wait-SandboxReady instead.
            $createCmd = "openshell sandbox create --name $Project --provider openrouter -- true"
            $r = Invoke-Wsl $createCmd
            Write-Host $r
            $passwordChanged = $true   # fresh sandbox, password file doesn't exist yet
            $needsUpload = $true
        }
        else {
            Write-Host "Sandbox '$Project' already exists."
        }

        # Wait for Ready *whether or not* we created — an existing sandbox can
        # be in Provisioning too (e.g. wedged from a prior crashed run, or just
        # slow on a cold start). All subsequent steps exec into the sandbox and
        # will fail with "phase: Provisioning" if we don't wait first.
        Write-Step "Waiting for sandbox '$Project' to reach Ready state"
        Wait-SandboxReady -Sandbox $Project
        Write-Host "Ready."

        # Self-heal: if the project dir isn't actually in the sandbox (e.g. a
        # prior run created the sandbox but its upload step was skipped — early
        # timeout, ctrl-c, error after create), upload now. Idempotent.
        $hasProjectDir = Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'test -d /sandbox/$Project && echo yes'"
        if ($hasProjectDir -notmatch 'yes') {
            if (-not $needsUpload) {
                Write-Host "Project dir missing in sandbox; will upload."
            }
            $needsUpload = $true
        }

        if ($needsUpload) {
            Write-Step "Uploading project files ($projectPath -> sandbox ~)"
            $uploadCmd = "openshell sandbox upload $Project '$wslProjectPath'"
            $u = Invoke-Wsl $uploadCmd
            Write-Host $u
        }

        # Make sure openrouter is attached. attach is idempotent.
        $attached = Invoke-Wsl "openshell sandbox provider list $Project 2>&1"
        if ($attached -notmatch '(^|\s)openrouter(\s|$)') {
            Write-Host "Attaching provider 'openrouter' to existing sandbox..."
            Invoke-Wsl "openshell sandbox provider attach $Project openrouter" | Out-Host
        }

        Write-Step "Writing opencode web password into sandbox"
        $pw = Get-OpencodeWebPassword
        Set-SandboxWebPassword -Sandbox $Project -Password $pw
        Write-Host "Wrote /sandbox/.opencode_web_env (mode 0600)."

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

        if (-not $NoRipgrep) {
            Write-Step "Ensuring ripgrep is installed in the sandbox (needed for opencode grep/glob)"
            $ok = Install-RipgrepInSandbox -Project $Project
            if ($ok) { Write-Host "ripgrep present at /sandbox/.local/bin/rg" -ForegroundColor DarkGray }
        }

        Write-Step "Starting opencode web inside sandbox"
        # NOTE on pattern: we use `opencode.web` (with `.` matching any char,
        # including the space) instead of `"opencode web"` because that nested
        # double-quoted pattern got mangled through the PS→wsl→openshell-exec
        # quoting layers, leaving pgrep seeing `pgrep -f opencode web` (two
        # args), failing, and the `|| echo NO` fallback wrongly reported the
        # process as missing — causing the script to spawn a second
        # opencode-web that crashed because 4096 was already bound.
        $running = Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'pgrep -fc opencode.web'"
        $isRunning = ([int]($running.Trim()) -gt 0)

        # If opencode-web is already running, verify its OPENCODE_SERVER_PASSWORD
        # env matches the canonical value in /sandbox/.opencode_web_env. We compare
        # SHA-256 hashes so neither side's plaintext ever appears in script output
        # or PS history. A mismatch means the process has stale env (e.g. from the
        # legacy provider that injected an opaque token) and must be restarted.
        $envIsStale = $false
        if ($isRunning) {
            $envCheck = 'f=$(grep ^OPENCODE_SERVER_PASSWORD= /sandbox/.opencode_web_env | cut -d= -f2- | sha256sum | cut -c1-16); p=$(pgrep -f opencode.web | head -1); e=$(tr "\0" "\n" </proc/$p/environ 2>/dev/null | grep ^OPENCODE_SERVER_PASSWORD= | cut -d= -f2- | sha256sum | cut -c1-16); [ "$f" = "$e" ] && echo MATCH || echo MISMATCH'
            $envState = Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c '$envCheck'"
            if ($envState -match 'MISMATCH') {
                $envIsStale = $true
                Write-Host "Running opencode web has stale env; will restart."
            }
        }

        $shouldRestart = $isRunning -and ($passwordChanged -or $envIsStale)
        if ($shouldRestart) {
            Invoke-Wsl "openshell sandbox exec -n $Project --no-tty -- bash -c 'pkill -f opencode.web; sleep 1'" | Out-Null
            $isRunning = $false
        }
        if (-not $isRunning) {
            # `set -a` exports every var defined while it's on; sources the env
            # file (which contains both OPENCODE_SERVER_PASSWORD and a PATH that
            # includes /sandbox/.local/bin so ripgrep is found); then turns
            # auto-export off and launches opencode-web with the loaded env.
            $startCmd = "openshell sandbox exec -n $Project --no-tty -- bash -c 'set -a && . /sandbox/.opencode_web_env && set +a && nohup opencode web --port $Port >/tmp/opencode-web.log 2>&1 & disown; sleep 2; pgrep -fc opencode.web'"
            $startResult = Invoke-Wsl $startCmd
            # The successful path returns a single number (pgrep count). Failure
            # paths return multi-line error messages that can't be int-parsed.
            $lastLine = ($startResult -split "`n" | Where-Object { $_ } | Select-Object -Last 1)
            $count = 0
            if ($lastLine -and [int]::TryParse($lastLine.Trim(), [ref]$count) -and $count -gt 0) {
                Write-Host "Started." -ForegroundColor Green
            }
            else {
                Write-Warning "opencode web didn't start cleanly. Output:"
                Write-Warning $startResult
                Write-Warning "Try: Show-OpencodeLogs $Project   (or the wrapper log: cat /tmp/opencode-web.log inside the sandbox)"
            }
        }
        else {
            Write-Host "opencode web already running in sandbox."
        }

        Write-Step "Ensuring port forward localhost:$Port -> sandbox:$Port"
        # openshell's own `-d` (background) flag is unreliable on systemd-user
        # sessions: the daemonized process gets killed shortly after the CLI
        # exits, leaving a `dead` forward in `openshell forward list`. Instead,
        # we wrap the foreground forward in a transient systemd-user unit which
        # IS reliably kept alive (and is auto-cleaned up by systemd on stop).
        $unit = Get-ForwardUnit -Project $Project -Port $Port
        if (Test-ForwardUnit -Unit $unit) {
            Write-Host "Forward already running ($unit)."
        }
        else {
            # Best-effort cleanup of any stale openshell-side entry from old
            # `-d` attempts, plus any failed previous systemd unit.
            Invoke-Wsl "systemctl --user stop $unit 2>/dev/null; systemctl --user reset-failed $unit 2>/dev/null; openshell forward stop $Port $Project 2>/dev/null; true" | Out-Null
            $r = Invoke-Wsl "systemd-run --user --unit=$unit -- openshell forward start 0.0.0.0:$Port $Project"
            Write-Host $r
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
        Write-Host "  Logs:     Show-OpencodeLogs $Project"
        Write-Host "  Stop:     Stop-Opencode $Project"
        Write-Host "  Recreate: Start-Opencode $Project -Recreate"
        Write-Host "  Rotate password: Start-Opencode $Project -RotatePassword"
        Write-Host ""
        Write-Host "Add an opencode plugin (e.g. session auto-rename):" -ForegroundColor DarkGray
        Write-Host '  wsl openshell sandbox connect <project>   # then inside the sandbox:' -ForegroundColor DarkGray
        Write-Host '  mkdir -p ~/.config/opencode && nano ~/.config/opencode/opencode.json' -ForegroundColor DarkGray
        Write-Host '  # add: { "plugin": ["opencode-session-auto-rename"] }, then Stop-Opencode + Start-Opencode' -ForegroundColor DarkGray

        if (-not $NoBrowser) {
            Start-Process $url
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

function global:Stop-Opencode {
    <#
    .SYNOPSIS
        Stops opencode web in a sandbox and removes the port forward.
    .DESCRIPTION
        Idempotent: silently no-ops if opencode web isn't running or no forward
        exists. Does NOT delete the sandbox itself — use `wsl openshell sandbox
        delete <name>` for that, or `Start-Opencode <name> -Recreate` to rebuild.
    .PARAMETER Project
        Sandbox name.
    .PARAMETER Port
        Local port the forward is bound to. Default 4096.
    .PARAMETER Distro
        WSL distro that has OpenShell installed. Default Ubuntu-24.04.
    .EXAMPLE
        Stop-Opencode liftosaur
    .EXAMPLE
        Stop-Opencode trvl -Port 4097
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]$Project,

        [Parameter()]
        [ValidateRange(1024, 65535)]
        [int]$Port = 4096,

        [Parameter()]
        [string]$Distro = 'Ubuntu-24.04'
    )

    $info = wsl -d $Distro -- bash -lc "openshell sandbox get $Project 2>&1" 2>&1
    if (($info -join "`n") -notmatch 'Phase:\s*Ready') {
        Write-Host "Sandbox '$Project' is not Ready (or doesn't exist); skipping opencode web kill." -ForegroundColor DarkGray
    }
    else {
        Write-Host "Stopping opencode web in '$Project'..."
        wsl -d $Distro -- bash -lc "openshell sandbox exec -n $Project --no-tty -- bash -c 'pkill -f \""opencode web\"" 2>/dev/null; true'" 2>&1 | Out-Null
    }

    Write-Host "Stopping forward on :$Port..."
    # Stop both the systemd-user wrapper unit AND any openshell-side state (in
    # case the user previously used the `-d` flag manually). Both are no-ops
    # if the thing isn't there.
    $unit = "opencode-fwd-$Project-$Port"
    wsl -d $Distro -- bash -lc "systemctl --user stop $unit 2>/dev/null; systemctl --user reset-failed $unit 2>/dev/null; openshell forward stop $Port $Project 2>&1; true" 2>&1 |
        Where-Object { $_ -notmatch '^\s*<\d>WSL' -and $_ -notmatch 'getpwuid\(\d+\) failed' -and $_ -notmatch 'no such forward' } |
        ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    Write-Host "Done." -ForegroundColor Green
}

function global:Show-OpencodeLogs {
    <#
    .SYNOPSIS
        Tails the opencode web log inside a sandbox. Ctrl-C to exit.
    .PARAMETER Project
        Sandbox name.
    .PARAMETER Lines
        Number of past lines to print before following. Default 50.
    .PARAMETER NoFollow
        Print the last N lines and exit (do not follow).
    .PARAMETER Distro
        WSL distro that has OpenShell installed. Default Ubuntu-24.04.
    .EXAMPLE
        Show-OpencodeLogs liftosaur
    .EXAMPLE
        Show-OpencodeLogs liftosaur -NoFollow -Lines 200
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]$Project,

        [Parameter()]
        [ValidateRange(1, 10000)]
        [int]$Lines = 50,

        [Parameter()]
        [switch]$NoFollow,

        [Parameter()]
        [string]$Distro = 'Ubuntu-24.04'
    )

    # Pass tail args separately, no nested quoting and no fallback echo (the
    # earlier "(log file not yet present)" fallback tripped bash's subshell
    # parser through the PS→wsl→openshell-exec→bash layers). tail prints its
    # own error if the file is missing, which is fine.
    if ($NoFollow) {
        wsl -d $Distro -- openshell sandbox exec -n $Project -- tail -n $Lines /tmp/opencode-web.log
    }
    else {
        wsl -d $Distro -- openshell sandbox exec -n $Project -- tail -n $Lines -f /tmp/opencode-web.log
    }
}

function global:Set-OpencodeEgress {
    <#
    .SYNOPSIS
        Add or remove outbound domain allowances on a running Opencode sandbox.
        Policy is hot-reloaded — no opencode-web restart needed.
    .DESCRIPTION
        Sandbox egress is locked down by default; only opencode.ai endpoints
        (plus npm and the openrouter provider) are allowed. Use this cmdlet at
        runtime when opencode reports a policy_denied and you want to grant
        access to a specific domain — e.g. when its webfetch hits a host you
        actually want to permit.

        For each domain passed, the cmdlet adds (or removes) both the apex
        (`<domain>:443`) and a subdomain wildcard (`*.<domain>:443`), so a
        single argument covers `github.com` and `api.github.com` /
        `raw.githubusercontent.com` etc.

        openshell rejects bare-TLD wildcards (`*.com`); only `*.<apex>` is
        permitted. You can't grant "any HTTPS" with a single rule — you have to
        name the apex domains you want.

        Idempotent: re-allowing an already-allowed domain is a no-op (openshell
        reports "Policy unchanged").
    .PARAMETER Project
        Sandbox name.
    .PARAMETER Allow
        One or more apex domains to allow outbound HTTPS to. Comma-separated
        or array. Each gets both `<domain>:443` and `*.<domain>:443`.
    .PARAMETER Deny
        One or more apex domains to remove. Reverses a previous `-Allow`.
    .PARAMETER Port
        Port for the rule (default 443).
    .PARAMETER Distro
        WSL distro. Default Ubuntu-24.04.
    .EXAMPLE
        Set-OpencodeEgress scripts -Allow github.com
        # Allows github.com + *.github.com (covers raw.githubusercontent isn't a
        # subdomain of github.com — see note below).
    .EXAMPLE
        Set-OpencodeEgress scripts -Allow github.com,githubusercontent.com,stackoverflow.com,pypi.org
        # Add several at once.
    .EXAMPLE
        Set-OpencodeEgress scripts -Deny duckduckgo.com
        # Undo a previous allow.
    .NOTES
        `raw.githubusercontent.com` lives on the *githubusercontent.com* apex,
        not *github.com*. If the agent needs raw GitHub files, allow both.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Allow')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]$Project,

        [Parameter(Mandatory = $true, ParameterSetName = 'Allow')]
        [string[]]$Allow,

        [Parameter(Mandatory = $true, ParameterSetName = 'Deny')]
        [string[]]$Deny,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 443,

        [Parameter()]
        [string]$Distro = 'Ubuntu-24.04'
    )

    function _wsl ([string]$cmd) {
        $raw = wsl -d $Distro -- bash -lc $cmd 2>&1
        $clean = $raw | Where-Object {
            $_ -notmatch '^\s*<\d>WSL' -and $_ -notmatch 'getpwuid\(\d+\) failed'
        }
        return (($clean | ForEach-Object { $_.ToString() }) -join "`n") -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    }

    $binFlags = '--binary /usr/local/bin/opencode --binary /usr/bin/node --binary /usr/lib/node_modules/opencode-ai/bin/.opencode'

    if ($Allow) {
        Write-Host "Allowing $($Allow -join ', ') (+ subdomains) on sandbox '$Project' (port $Port)..."
        $adds = ($Allow | ForEach-Object {
                "--add-endpoint '${_}:${Port}' --add-endpoint '*.${_}:${Port}'"
            }) -join ' '
        _wsl "openshell policy update $Project $adds $binFlags --wait" | Out-Host
    }
    elseif ($Deny) {
        Write-Host "Removing $($Deny -join ', ') (+ subdomains) from sandbox '$Project' (port $Port)..."
        $rms = ($Deny | ForEach-Object {
                "--remove-endpoint ${_}:${Port} --remove-endpoint *.${_}:${Port}"
            }) -join ' '
        _wsl "openshell policy update $Project $rms --wait" | Out-Host
    }
}

function global:Get-OpencodeStatus {
    <#
    .SYNOPSIS
        Print a one-page overview of the Opencode setup: gateway, sandboxes,
        forwards, and which sandboxes have opencode-web actually serving.
    .DESCRIPTION
        Useful when you've forgotten what's running, what's wedged, and which
        port goes where. Calls `openshell` and `systemctl --user` under the hood.
    .PARAMETER Distro
        WSL distro to query. Default Ubuntu-24.04.
    .EXAMPLE
        Get-OpencodeStatus
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string]$Distro = 'Ubuntu-24.04'
    )

    function _wsl([string]$cmd) {
        $raw = wsl -d $Distro -- bash -lc $cmd 2>&1
        $clean = $raw | Where-Object {
            $_ -notmatch '^\s*<\d>WSL' -and $_ -notmatch 'getpwuid\(\d+\) failed'
        }
        return (($clean | ForEach-Object { $_.ToString() }) -join "`n") -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    }

    Write-Host ""
    Write-Host "=== Gateway ===" -ForegroundColor Cyan
    $gw = _wsl 'openshell status 2>&1'
    if ($gw -match 'Connected') {
        Write-Host "  Connected" -ForegroundColor Green
    }
    else {
        Write-Host "  NOT Connected" -ForegroundColor Red
        Write-Host "  $($gw -replace '`r','' -replace '`n', ' ' | Out-String)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "=== Sandboxes ===" -ForegroundColor Cyan
    $list = _wsl 'openshell sandbox list 2>&1'
    if ($list -match 'No sandboxes found' -or [string]::IsNullOrWhiteSpace($list)) {
        Write-Host "  (none)" -ForegroundColor DarkGray
    }
    else {
        # Skip header line; parse name + phase for our own per-sandbox augment.
        $sandboxNames = @()
        foreach ($line in ($list -split "`n")) {
            $cols = ($line -split '\s+') | Where-Object { $_ }
            if ($cols.Count -ge 1 -and $cols[0] -and $cols[0] -ne 'NAME') {
                $sandboxNames += $cols[0]
            }
        }
        Write-Host $list

        # Per-sandbox: is opencode-web running inside? what dirs in /sandbox?
        foreach ($name in $sandboxNames) {
            $info = _wsl "openshell sandbox get $name 2>&1 | grep -E 'Phase:'"
            $isReady = $info -match 'Ready'
            if ($isReady) {
                $webCount = _wsl "openshell sandbox exec -n $name --no-tty -- bash -c 'pgrep -fc opencode.web' 2>/dev/null"
                $dirs = _wsl "openshell sandbox exec -n $name --no-tty -- bash -c 'ls -1 /sandbox | grep -v ^\\. | head -10' 2>/dev/null"
                $hasWeb = ([int]($webCount.Trim()) -gt 0)
                Write-Host "  $name :" -ForegroundColor White
                Write-Host "    opencode web running: $(if ($hasWeb) {'yes'} else {'NO'})"
                if ($dirs) {
                    Write-Host "    project dirs in /sandbox:"
                    foreach ($d in ($dirs -split "`n" | Where-Object { $_ })) {
                        Write-Host "      $d"
                    }
                }
            }
        }
    }

    Write-Host ""
    Write-Host "=== Port forwards ===" -ForegroundColor Cyan
    # openshell's own list (may include dead entries)
    $fwd = _wsl 'openshell forward list 2>&1'
    Write-Host $fwd
    # systemd-user units that wrap our reliable forwards
    $units = _wsl "systemctl --user list-units --type=service --no-legend --plain 2>/dev/null | grep '^opencode-fwd-'"
    if ($units -and -not [string]::IsNullOrWhiteSpace($units)) {
        Write-Host ""
        Write-Host "  systemd-managed (the ones Start-Opencode creates):"
        foreach ($u in ($units -split "`n" | Where-Object { $_ })) {
            Write-Host "    $u" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "=== Tip ===" -ForegroundColor DarkGray
    Write-Host "  Start:   Start-Opencode <project>" -ForegroundColor DarkGray
    Write-Host "  Stop:    Stop-Opencode <project>" -ForegroundColor DarkGray
    Write-Host "  Rebuild: Start-Opencode <project> -Recreate" -ForegroundColor DarkGray
    Write-Host ""
}
