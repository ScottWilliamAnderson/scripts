# PowerShell Profile Script

# Function to log timing information
function Log-Timing {
    param (
        [string]$section,
        [datetime]$startTime,
        [datetime]$endTime
    )
    $duration = $endTime - $startTime
    $logEntry = "$section - Start: $startTime, End: $endTime, Duration: $duration"
    Add-Content -Path "$PSScriptRoot\profile_timing.log" -Value $logEntry
}

# Profile Setup

# Check for required environment variables
if (-not $env:USERPROFILE) {
    Write-Host "USERPROFILE environment variable is not set. Skipping profile import."
    return
}

# Timing for Chocolatey profile import
$chocoStartTime = Get-Date
# Import chocolatey profile so it can run refreshenv command
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
$chocoEndTime = Get-Date
Log-Timing -section "Chocolatey Profile Import" -startTime $chocoStartTime -endTime $chocoEndTime

# Timing for environment variables refresh
$envStartTime = Get-Date
# Refresh environment variables
refreshenv
$envEndTime = Get-Date
Log-Timing -section "Environment Variables Refresh" -startTime $envStartTime -endTime $envEndTime

# Timing for posh-git import
$poshGitStartTime = Get-Date
# Import posh-git
Import-Module posh-git
$poshGitEndTime = Get-Date
Log-Timing -section "Posh-Git Import" -startTime $poshGitStartTime -endTime $poshGitEndTime

# Timing for oh-my-posh theme import
$ompStartTime = Get-Date
# Import oh-my-posh theme
oh-my-posh init pwsh --config "$repoPath\oh-my-posh\plenty-of-info.omp.json" | Invoke-Expression
$ompEndTime = Get-Date
Log-Timing -section "Oh-My-Posh Theme Import" -startTime $ompStartTime -endTime $ompEndTime

# Uncomment the following line to enable default behaviour of clearing the terminal screen after the profile setup
# clear

# Useful Functions

# Autoupdate mechanism
function pull-profile {
    # Store the current directory to navigate back
    $currentDir = Get-Location

    # Navigate to the repository directory
    Set-Location $repoPath

    # Pull the latest changes from the repository
    git pull

    # Refresh the PowerShell profile
    . $PROFILE

    # Navigate back to where we started
    Set-Location $currentDir
}

# sudo command to open an admin terminal
function sudo {
    Start-Process -verb RunAs wt
}

# sleep function to pause execution for a specified number of seconds
function sleep {
    param (
        [int]$seconds
    )
    
    Start-Sleep -Seconds $seconds
}

# mklink function to create symbolic links
function mklink { 
    cmd /c mklink $args 
}
