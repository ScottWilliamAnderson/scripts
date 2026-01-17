# GPG Agent Setup Script

function start-gpg-agent {
    <#
    .SYNOPSIS
        Starts the GPG agent if GPG signing is configured for git.
    .DESCRIPTION
        Checks if git commit signing is enabled and GPG is installed,
        then starts the gpg-agent if needed. Silently succeeds if
        GPG signing is not configured (for multi-machine compatibility).
    .OUTPUTS
        None
    #>
    
    # Check if git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return
    }
    
    # Check if GPG signing is enabled for git
    $gpgSign = git config --global --get commit.gpgsign 2>$null
    if ($gpgSign -ne "true") {
        return  # GPG signing not enabled, skip silently
    }
    
    # Get the configured GPG program
    $gpgProgram = git config --global --get gpg.program 2>$null
    if (-not $gpgProgram -or -not (Test-Path $gpgProgram)) {
        return  # GPG program not found, skip silently
    }
    
    # Start gpg-agent using gpg-connect-agent
    $gpgConnectAgent = Join-Path (Split-Path $gpgProgram) "gpg-connect-agent.exe"
    if (Test-Path $gpgConnectAgent) {
        & $gpgConnectAgent reloadagent /bye 2>$null | Out-Null
    }
}
