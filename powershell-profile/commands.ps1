# Command List and Execution Script
# Optimized for fast startup using background loading and .NET APIs

# Signal that profile is still loading (for Oh-My-Posh indicator)
$env:PROFILE_LOADING = "true"

# Track if posh-git has been loaded
$global:PoshGitLoaded = $false

# Record start time for logging
$script:profileStartTime = [DateTime]::Now

# PHASE 1: Blocking operations (must complete before prompt appears)

# Oh-My-Posh Theme - must load before the prompt appears
$ompStartTime = [DateTime]::Now
$ompConfigPath = [System.IO.Path]::Combine($repoPath, "oh-my-posh", "plenty-of-info.omp.json")
oh-my-posh init pwsh --config $ompConfigPath | Invoke-Expression
$ompEndTime = [DateTime]::Now

if ($enableLogging) {
    Log-Timing -section "Oh-My-Posh Theme (blocking)" -startTime $ompStartTime -endTime $ompEndTime
}

# GitHub Copilot
$copilotStartTime = [DateTime]::Now
$ghCopilotProfile = [System.IO.Path]::Combine((Split-Path -Path $PROFILE -Parent), "gh-copilot.ps1")
if ([System.IO.File]::Exists($ghCopilotProfile)) {
    . $ghCopilotProfile
}
if ($enableLogging) {
    Log-Timing -section "GitHub Copilot (blocking)" -startTime $copilotStartTime -endTime ([DateTime]::Now)
}

# PHASE 2: Lazy-loaded Chocolatey (only loads when refreshenv is called)

function global:refreshenv {
    <#
    .SYNOPSIS
        Refreshes environment variables from the registry (lazy-loads Chocolatey profile).
    #>
    $chocoStartTime = [DateTime]::Now
    
    # Import the actual Chocolatey profile
    $chocoProfilePath = [System.IO.Path]::Combine($env:ChocolateyInstall, "helpers", "chocolateyProfile.psm1")
    Import-Module $chocoProfilePath -Global
    
    if ($enableLogging) {
        Log-Timing -section "Chocolatey Profile (lazy)" -startTime $chocoStartTime -endTime ([DateTime]::Now)
    }
    
    # Replace this function with the real Update-SessionEnvironment
    Set-Alias -Name refreshenv -Value Update-SessionEnvironment -Scope Global -Force
    
    # Call it now
    Update-SessionEnvironment
}

# PHASE 3: Background loading (runs after prompt appears)

# Check if ThreadJob module is available (built into PS 7+)
$useBackgroundLoading = $null -ne (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)

if ($useBackgroundLoading) {
    # Start background job to run non-module operations (git config, gpg)
    # Note: Module imports (posh-git) must happen in main session, so we defer them
    $null = Start-ThreadJob -Name "ProfileBackgroundLoad" -ScriptBlock {
        param($repoPath)
        
        $results = @{}
        
        # Git Config (this writes to global git config, so it works from background)
        $startTime = [DateTime]::Now
        try {
            $gitConfigPath = [System.IO.Path]::Combine($repoPath, "git-config", "git-config.ps1")
            . $gitConfigPath
            setup-git
            $results["git-config"] = @{ Success = $true; Duration = (([DateTime]::Now) - $startTime).TotalMilliseconds }
        } catch {
            $results["git-config"] = @{ Success = $false; Error = $_.Exception.Message }
        }
        
        # GPG Agent (starts external process, works from background)
        $startTime = [DateTime]::Now
        try {
            $gpgSetupPath = [System.IO.Path]::Combine($repoPath, "powershell-profile", "gpg-setup.ps1")
            . $gpgSetupPath
            start-gpg-agent
            $results["gpg-agent"] = @{ Success = $true; Duration = (([DateTime]::Now) - $startTime).TotalMilliseconds }
        } catch {
            $results["gpg-agent"] = @{ Success = $false; Error = $_.Exception.Message }
        }
        
        return $results
    } -ArgumentList $repoPath
    
    # Register an event to clean up background job when it completes (or fails)
    $null = Register-ObjectEvent -InputObject (Get-Job -Name "ProfileBackgroundLoad") -EventName StateChanged -Action {
        if ($Event.Sender.State -in @("Completed", "Failed", "Stopped")) {
            # Clean up the job
            Remove-Job -Name "ProfileBackgroundLoad" -Force -ErrorAction SilentlyContinue
        }
    } -SupportEvent
    
    # Deferred loading: Load posh-git on first command
    # We wrap the prompt function to check and load on first invocation
    $global:OriginalPrompt = $function:prompt
    $global:DeferredLoadComplete = $false
    
    function global:prompt {
        # On first prompt after initial display, load deferred modules
        if (-not $global:DeferredLoadComplete) {
            $global:DeferredLoadComplete = $true
            
            # Load posh-git (needed for tab completions)
            if (-not $global:PoshGitLoaded) {
                Import-Module posh-git -ErrorAction SilentlyContinue
                $global:PoshGitLoaded = $true
            }
            
            # Mark loading complete
            $env:PROFILE_LOADING = "false"
        }
        
        # Call the original Oh-My-Posh prompt
        & $global:OriginalPrompt
    }
    
} else {
    # Fallback: Sequential loading if ThreadJob is not available
    Write-Verbose "ThreadJob not available, using sequential loading"
    
    # Git Config (scripts already sourced in profile.ps1, but setup-git needs to be called)
    $startTime = [DateTime]::Now
    setup-git
    if ($enableLogging) { Log-Timing -section "Git Config" -startTime $startTime -endTime ([DateTime]::Now) }
    
    # Posh-Git
    $startTime = [DateTime]::Now
    Import-Module posh-git -ErrorAction SilentlyContinue
    $global:PoshGitLoaded = $true
    if ($enableLogging) { Log-Timing -section "Posh-Git" -startTime $startTime -endTime ([DateTime]::Now) }
    
    # GPG Agent (start-gpg-agent is defined in gpg-setup.ps1, already sourced in profile.ps1)
    $startTime = [DateTime]::Now
    start-gpg-agent
    if ($enableLogging) { Log-Timing -section "GPG Agent" -startTime $startTime -endTime ([DateTime]::Now) }
    
    # Mark loading complete
    $env:PROFILE_LOADING = "false"
}

# Log prompt ready time
if ($enableLogging) {
    $promptReadyTime = [DateTime]::Now
    $promptDuration = $promptReadyTime - $script:profileStartTime
    $logPath = [System.IO.Path]::Combine($PSScriptRoot, "profile_timing.log")
    Add-Content -Path $logPath -Value "Prompt Ready - Duration: $($promptDuration.TotalMilliseconds)ms (deferred loading on first command)"
}
