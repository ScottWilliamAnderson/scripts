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

# Check if logging is enabled
$enableLogging = $false
if ($env:ENABLE_PROFILE_LOGGING -eq "true") {
    $enableLogging = $true
}

# List of commands to run and their descriptions
$commands = @(
    @{ Command = { Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1 }; Description = "Chocolatey Profile Import" },
    @{ Command = { refreshenv }; Description = "Environment Variables Refresh" },
    @{ Command = { Import-Module posh-git }; Description = "Posh-Git Import" },
    @{ Command = { oh-my-posh init pwsh --config "$repoPath\oh-my-posh\plenty-of-info.omp.json" | Invoke-Expression }; Description = "Oh-My-Posh Theme Import" }
)

# Run each command and log timing if enabled
foreach ($cmd in $commands) {
    $startTime = Get-Date
    & $cmd.Command
    $endTime = Get-Date
    if ($enableLogging) {
        Log-Timing -section $cmd.Description -startTime $startTime -endTime $endTime
    }
}

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
