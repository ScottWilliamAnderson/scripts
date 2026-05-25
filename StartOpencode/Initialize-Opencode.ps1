# Defines the Initialize-Opencode function for one-time setup / migration of
# the OpenShell + opencode workflow. Dot-source from your PowerShell profile.

function global:Initialize-Opencode {
    <#
    .SYNOPSIS
        One-time setup (or migration) for the OpenShell + opencode workflow.
    .DESCRIPTION
        Configures WSL so the OpenShell gateway runs under your normal (non-root)
        user with the right MicroVM driver and auto-starts at WSL boot.

        Works for two starting points and detects which one applies:
          - Fresh install: openshell was installed as your own user. The function
            just ensures the driver env file, gateway enable, lingering, gateway
            registration, and openrouter provider are in place.
          - Migration: openshell was installed as root first (e.g. the install
            script was curl|sh'd before a normal user existed). Adds cleanup
            steps to disable root's lingering/autostart and wipe stale TLS that
            was copied from root.

        Idempotent: safe to re-run; each step checks state and skips if already
        done.

        Cost of migration: any sandboxes previously created under root's state
        directory will not be visible under your user. Recreate them as needed
        via `Start-Opencode <project>` (one command per project).
    .PARAMETER User
        WSL user that will own the gateway. Defaults to the `default=` entry
        in /etc/wsl.conf, falling back to the current `whoami` in WSL.
    .PARAMETER Distro
        WSL distro that has OpenShell installed. Default Ubuntu-24.04.
    .PARAMETER SkipOpenRouter
        Skip prompting for the OpenRouter API key. Use if you intend to set up
        the provider manually later.
    .EXAMPLE
        Initialize-Opencode
        # Full setup, prompts for sudo password (once) and OpenRouter key.
    .EXAMPLE
        Initialize-Opencode -SkipOpenRouter
        # Same but don't prompt for the OpenRouter key; configure that yourself.
    .NOTES
        File Name      : Initialize-Opencode.ps1
        Prerequisite   : WSL with Ubuntu-24.04 (glibc >= 2.38), OpenShell installed
                         in WSL (the .deb package, providing the systemd user unit).
        Copyright      : Scott Anderson 2026
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string]$User,
        [Parameter()][string]$Distro = 'Ubuntu-24.04',
        [Parameter()][switch]$SkipOpenRouter
    )

    # --- Local helpers ---------------------------------------------------

    function Write-Step ([string]$Message) {
        Write-Host ""
        Write-Host "==> $Message" -ForegroundColor Cyan
    }

    function Invoke-Wsl ([string]$Command) {
        $raw = wsl -d $Distro -- bash -lc $Command 2>&1
        $clean = $raw | Where-Object {
            $_ -notmatch '^\s*<\d>WSL' -and $_ -notmatch 'getpwuid\(\d+\) failed'
        }
        $joined = ($clean | ForEach-Object { $_.ToString() }) -join "`n"
        # Strip ANSI escapes so regex parsing of openshell output works.
        return $joined -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    }

    function Invoke-WslSudo ([string]$Script) {
        # Run a bash script with sudo inside WSL without using stdin pipes
        # (which break sudo's password prompt in some PS/WSL combinations).
        # We write to a Windows tempfile with LF line endings and tell sudo
        # bash to execute that file directly. Sudo can then read its password
        # from /dev/tty normally.
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            $normalized = $Script -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($tmp, $normalized, [System.Text.UTF8Encoding]::new($false))
            $drive = $tmp.Substring(0, 1).ToLower()
            $wslTmp = "/mnt/$drive" + ($tmp.Substring(2) -replace '\\', '/')
            wsl -d $Distro -- sudo bash $wslTmp
            return $LASTEXITCODE
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
    }

    # --- Preflight -------------------------------------------------------

    try {
        Write-Step "Preflight checks"

        $check = Invoke-Wsl 'which openshell && which openshell-gateway && ls /usr/lib/systemd/user/openshell-gateway.service'
        if (-not $check) {
            throw "openshell binary or systemd unit not found in $Distro. Install openshell first: curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh"
        }

        if (-not $User) {
            $User = (Invoke-Wsl 'grep "^default=" /etc/wsl.conf 2>/dev/null | head -1 | cut -d= -f2 | tr -d "[:space:]"').Trim()
            if (-not $User) { $User = (Invoke-Wsl 'whoami').Trim() }
        }

        $uid = (Invoke-Wsl "id -u $User 2>/dev/null").Trim()
        if (-not $uid -or $uid -notmatch '^\d+$') {
            throw "User '$User' not found in $Distro. Create it first or pass -User <name>."
        }

        # Decide which compute driver to use. Prefer Docker because the alpha
        # MicroVM driver in openshell 0.0.47 has supervisor-session bugs that
        # leave sandboxes wedged in Provisioning. Fall back to vm only if
        # Docker Desktop integration isn't available.
        $dockerOk = (Invoke-Wsl 'docker info >/dev/null 2>&1 && echo OK') -match 'OK'
        $kvm = Invoke-Wsl 'test -c /dev/kvm && echo OK'
        if ($dockerOk) {
            $driver = 'docker'
        }
        elseif ($kvm -match 'OK') {
            $driver = 'vm'
            Write-Warning "Docker Desktop WSL integration isn't enabled for this distro. Falling back to the 'vm' driver, which is alpha and has known supervisor-session bugs in openshell 0.0.47. For a more reliable setup, enable WSL integration in Docker Desktop -> Settings -> Resources -> WSL Integration, then re-run Initialize-Opencode."
        }
        else {
            throw "No usable compute driver: docker is unreachable and /dev/kvm is missing. Enable Docker Desktop WSL integration or fix KVM access, then retry."
        }

        # --- Detect existing state --------------------------------------

        # Migration case: root already has the gateway service enabled (autostart symlink exists).
        $rootHasService = (Invoke-Wsl 'sudo -n test -f /root/.config/systemd/user/default.target.wants/openshell-gateway.service 2>/dev/null && echo yes')
        $rootHasGateway = ($rootHasService -match 'yes')

        # Already-migrated case: user has the gateway enabled.
        $userHasService = (Invoke-Wsl "test -L /home/$User/.config/systemd/user/default.target.wants/openshell-gateway.service && echo yes")
        $userHasGateway = ($userHasService -match 'yes')

        # User in the right group for the chosen driver?
        $needGroup = if ($driver -eq 'docker') { 'docker' } else { 'kvm' }
        $inGroup = (Invoke-Wsl "id $User 2>/dev/null | grep -c '\b${needGroup}\b'")
        $userInGroup = ([int]($inGroup.Trim()) -gt 0)
        # Keep the old var name for the planning output (semantically: in driver group)
        $userInKvm = $userInGroup

        # Lingering for user?
        $linger = (Invoke-Wsl "loginctl show-user $User 2>/dev/null | grep -i '^Linger=yes'")
        $userLingers = -not [string]::IsNullOrWhiteSpace($linger)

        # Env file matches what we want?
        $targetEnv = "OPENSHELL_DRIVERS=${driver}`nOPENSHELL_BIND_ADDRESS=0.0.0.0`n"
        $currentEnv = Invoke-Wsl "cat /home/$User/.config/openshell/gateway.env 2>/dev/null"
        $currentDriver = (Invoke-Wsl "grep -h OPENSHELL_DRIVERS /home/$User/.config/openshell/gateway.env 2>/dev/null | cut -d= -f2 | tr -d '[:space:]'").Trim()
        $envChanging = (($currentEnv -replace "`r", "").Trim() -ne $targetEnv.Trim())
        $driverChanging = $envChanging   # legacy var name; same semantics now

        # Gateway currently up? If it's down, a WSL restart is almost always part of the cure
        # (group changes need a fresh user manager; a crashed service needs the env it failed on).
        $gatewayUp = (Invoke-Wsl 'openshell status 2>&1') -match 'Connected'

        Write-Host "User                : $User (uid $uid)"
        Write-Host "WSL distro          : $Distro"
        Write-Host "Compute driver      : $driver $(if ($driver -eq 'vm') {'(MicroVM, alpha)'} else {''})"
        Write-Host "Docker reachable    : $(if ($dockerOk) {'yes'} else {'no'})"
        Write-Host "/dev/kvm            : $(if ($kvm -match 'OK') {'available'} else {'missing'})"
        Write-Host "Root owns gateway   : $(if ($rootHasGateway) {'yes (will migrate)'} else {'no'})"
        Write-Host "User has gateway    : $(if ($userHasGateway) {'yes'} else {'no (will enable)'})"
        Write-Host "User in $needGroup group : $(if ($userInGroup) {'yes'} else {'no (will add)'})"
        Write-Host "User lingering      : $(if ($userLingers) {'yes'} else {'no (will enable)'})"
        Write-Host "Gateway status      : $(if ($gatewayUp) {'Connected'} else {'NOT connected'})"
        Write-Host "Configured driver   : $(if ($currentDriver) {$currentDriver} else {'(none)'}) -> $driver"

        $needsWslRestart = ($rootHasGateway -or -not $userInGroup -or $driverChanging -or -not $gatewayUp)
        $alreadyDone = $userHasGateway -and $userInGroup -and $userLingers -and -not $rootHasGateway -and $gatewayUp -and -not $driverChanging
        if ($alreadyDone) {
            Write-Host ""
            Write-Host "Configuration looks already in place. Only checking gateway status and openrouter provider." -ForegroundColor Green
        }

        # --- Confirmation -----------------------------------------------

        Write-Host ""
        Write-Host "Plan:" -ForegroundColor Yellow
        if ($rootHasGateway) {
            Write-Host "  - Remove root's gateway autostart + lingering." -ForegroundColor Yellow
            Write-Host "  - Wipe stale openshell config in $User's home (copied from root)." -ForegroundColor Yellow
            Write-Host "  - Any sandboxes previously created under root will become invisible." -ForegroundColor Yellow
        }
        if (-not $userInGroup) { Write-Host "  - Add $User to $needGroup group (driver=$driver needs it)." -ForegroundColor Yellow }
        if (-not $userLingers) { Write-Host "  - Enable lingering for $User." -ForegroundColor Yellow }
        if (-not $userHasGateway) { Write-Host "  - Enable openshell-gateway service for $User." -ForegroundColor Yellow }
        Write-Host "  - Write ~/.config/openshell/gateway.env (driver=$driver)." -ForegroundColor Yellow
        if ($needsWslRestart) {
            Write-Host "  - Restart WSL (wsl --shutdown) so the new group/state takes effect." -ForegroundColor Yellow
        }
        if (-not $SkipOpenRouter) {
            Write-Host "  - Prompt for OpenRouter API key (only if provider doesn't already exist)." -ForegroundColor Yellow
        }
        Write-Host ""
        $ans = Read-Host "Proceed? [y/N]"
        if ($ans -notmatch '^(y|yes)$') {
            Write-Host "Cancelled."
            return
        }

        # --- Single privileged batch ------------------------------------

        Write-Step "Step 1/9: Privileged setup (sudo prompt below)"
        $cleanupRoot = if ($rootHasGateway) {
            @"
loginctl disable-linger root 2>/dev/null || true
systemctl stop user@0.service 2>/dev/null || true
rm -f /root/.config/systemd/user/default.target.wants/openshell-gateway.service
# Wipe stale config that was copied from root and won't match user's fresh certs.
rm -rf /home/$User/.config/openshell /home/$User/.local/state/openshell
"@
        } else { '' }

        $addGroup = if (-not $userInGroup) { "usermod -aG $needGroup $User" } else { '' }
        $enableLinger = if (-not $userLingers) { "loginctl enable-linger $User" } else { '' }

        $sudoScript = @"
set -e
$cleanupRoot
$addGroup
$enableLinger
mkdir -p /home/$User/.config/openshell
chown -R ${User}: /home/$User/.config/openshell

# Enable the gateway service for $User by creating the wants-symlink.
# (We can't run 'systemctl --user enable' as another user without a live
# session; the symlink has the same effect.)
mkdir -p /home/$User/.config/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/openshell-gateway.service \
       /home/$User/.config/systemd/user/default.target.wants/openshell-gateway.service
chown -R ${User}: /home/$User/.config/systemd
"@
        $rc = Invoke-WslSudo -Script $sudoScript
        if ($rc -ne 0) {
            throw "Privileged setup failed (exit $rc). See messages above."
        }

        # --- User-side configuration ------------------------------------

        Write-Step "Step 2/9: Writing gateway env file (driver=$driver, bind=0.0.0.0)"
        # Bind to 0.0.0.0 (not 127.0.0.1) so sandbox containers can reach the
        # gateway from their Docker bridge interface (resolved via
        # host.openshell.internal). mTLS still protects the listener.
        Invoke-Wsl "printf 'OPENSHELL_DRIVERS=$driver\nOPENSHELL_BIND_ADDRESS=0.0.0.0\n' > /home/$User/.config/openshell/gateway.env"
        $envCheck = Invoke-Wsl "cat /home/$User/.config/openshell/gateway.env"
        Write-Host "  $envCheck"

        Write-Step "Step 3/9: Gateway service is enabled for $User"
        Write-Host "  (Symlink created in the privileged step.)"

        # --- Restart WSL so the new group takes effect ------------------

        if ($needsWslRestart) {
            Write-Step "Step 4/9: Restarting WSL (group memberships only refresh after relog)"
            Write-Host "  Running: wsl --shutdown"
            wsl --shutdown
            Start-Sleep -Seconds 2
            Write-Host "  Bringing $Distro back up..."
            # The first command will kickstart the distro and (with lingering) bring
            # up the user manager and the gateway service.
            Invoke-Wsl 'true' | Out-Null
        }
        else {
            Write-Step "Step 4/9: Skipping WSL restart (nothing changed that needs it)"
        }

        Write-Step "Step 5/9: Waiting for the gateway to come up under $User"
        $up = $false
        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Seconds 1
            # Use ss to check listening port directly, since `openshell status`
            # would need the gateway registration that we haven't created yet.
            $listening = Invoke-Wsl 'ss -tlnH 2>/dev/null | grep -c 127.0.0.1:17670'
            if ([int]($listening.Trim()) -gt 0) {
                $up = $true
                Write-Host "  Gateway listening on 127.0.0.1:17670 (after ${i}s)."
                break
            }
        }
        if (-not $up) {
            $jr = Invoke-Wsl "sudo journalctl --user-unit openshell-gateway --user -u openshell-gateway -n 30 --no-pager 2>&1 || sudo -u $User journalctl --user -u openshell-gateway -n 30 --no-pager"
            Write-Warning "Gateway didn't come up in 60s. Recent service logs:"
            Write-Warning $jr
            throw "Gateway failed to start."
        }

        Write-Step "Step 6/9: Registering the local gateway under $User"
        $reg = Invoke-Wsl "sudo -u $User openshell gateway list 2>&1"
        if ($reg -notmatch 'openshell\s+https://127\.0\.0\.1:17670') {
            $add = Invoke-Wsl "sudo -u $User openshell gateway add https://127.0.0.1:17670 --name openshell --local 2>&1"
            Write-Host "  $add"
        }
        else {
            Write-Host "  Gateway already registered."
        }

        Write-Step "Step 7/9: Verifying gateway status"
        $status = Invoke-Wsl "sudo -u $User openshell status 2>&1"
        if ($status -notmatch 'Connected') {
            Write-Warning "Gateway is listening but client reports not Connected:"
            Write-Warning $status
            throw "Gateway registration mismatch."
        }
        Write-Host "  Connected." -ForegroundColor Green

        # --- OpenRouter provider ----------------------------------------

        if ($SkipOpenRouter) {
            Write-Step "Step 8/9: Skipping OpenRouter provider (per -SkipOpenRouter)"
        }
        else {
            Write-Step "Step 8/9: Creating the openrouter provider"
            $hasOR = Invoke-Wsl "sudo -u $User openshell provider get openrouter 2>&1 | grep -i openrouter"
            if ($hasOR) {
                Write-Host "  openrouter provider already exists; skipping."
            }
            else {
                Write-Host "  Paste your OpenRouter API key (begins sk-or-...):" -ForegroundColor Yellow
                $sec = Read-Host -AsSecureString
                $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
                try {
                    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                    if ($key.Length -lt 10) {
                        Write-Warning "  Key looks empty/too short; skipping. Create the provider manually later."
                    }
                    else {
                        # Pipe `KEY=...\n` via stdin to bash inside WSL, run
                        # provider create with the env populated. Never goes
                        # through argv, never appears in process listings.
                        $tmp = [System.IO.Path]::GetTempFileName()
                        try {
                            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes("OPENROUTER_API_KEY=$key`n")
                            [System.IO.File]::WriteAllBytes($tmp, $bytes)
                            $wslTmp = "/mnt/c" + ($tmp.Substring(2) -replace '\\', '/').ToLower()
                            # Source the file (sets OPENROUTER_API_KEY in env) then run as scott
                            $script = "set -a && . '$wslTmp' && set +a && sudo --preserve-env=OPENROUTER_API_KEY -u $User openshell provider create --name openrouter --type generic --credential OPENROUTER_API_KEY"
                            $out = Invoke-Wsl $script
                            Write-Host "  $out"
                        }
                        finally {
                            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
                        }
                    }
                }
                finally {
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                }
            }
        }

        Write-Step "Step 9/9: Done"
        Write-Host ""
        Write-Host "OpenShell + opencode setup complete." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Gateway runs as : $User"
        Write-Host "  Autostarts at WSL boot via lingering."
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "  - Any old sandboxes were under root's state and are gone now."
        Write-Host "  - Create one for your first project: Start-Opencode liftosaur"
        if ($SkipOpenRouter) {
            Write-Host "  - You skipped the openrouter provider. Add it later via:"
            Write-Host "      wsl -- openshell provider create --name openrouter --type generic --credential OPENROUTER_API_KEY=sk-or-..."
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
