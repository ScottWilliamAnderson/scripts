# PowerShell Profile Script

# Function to log timing information
function Log-Timing {
    <#
    .SYNOPSIS
        Logs timing information for a specific section.
    .PARAMETER section
        The name of the section being logged.
    .PARAMETER startTime
        The start time of the section.
    .PARAMETER endTime
        The end time of the section.
    .OUTPUTS
        None
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$section,
        
        [Parameter(Mandatory = $true)]
        [datetime]$startTime,
        
        [Parameter(Mandatory = $true)]
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

function copilot-setup {
    <#
    .SYNOPSIS
        Sets up the github copilot profile.
    .PARAMETER Force
        Aliases: -f
        Forces regeneration of the copilot profile even if it exists.
    .OUTPUTS
        None
    #>
    param (
        [Alias("f")]
        [switch]$Force
    )

    # Run the command
    gh copilot --version > $null

    # Check the exit code
    if ($LASTEXITCODE -eq 0) {
        # if $GH_PROFILE is not set, set it to the default value
        if (-not $GH_COPILOT_PROFILE) {
            $GH_COPILOT_PROFILE = Join-Path -Path $(Split-Path -Path $PROFILE -Parent) -ChildPath "gh-copilot.ps1"
        }
        if ((-not (Test-Path $GH_COPILOT_PROFILE)) -or $Force) {
            gh copilot alias -- pwsh | Out-File ( New-Item -Path $GH_COPILOT_PROFILE -Force )
        }
        . $GH_COPILOT_PROFILE

    } else {
        Write-Output "Github Copilot is not installed or there was an error."
    }
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
    <#
    .SYNOPSIS
        Updates the profile from the Git repository and refreshes the PowerShell profile.
    .OUTPUTS
        None
    #>
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
    <#
    .SYNOPSIS
        Opens an elevated Windows Terminal.
    .OUTPUTS
        None
    #>
    Start-Process -verb RunAs wt
}

# sleep function to pause execution for a specified number of seconds
function sleep {
    <#
    .SYNOPSIS
        Pauses execution for a specified number of seconds.
    .PARAMETER seconds
        The number of seconds to pause execution.
    .OUTPUTS
        None
    #>
    param (
        [Parameter(Mandatory = $true)]
        [int]$seconds
    )
    
    Start-Sleep -Seconds $seconds
}

# mklink function to create symbolic links
function mklink { 
    <#
    .SYNOPSIS
        Creates symbolic links.
    .PARAMETER args
        The arguments to pass to the mklink command.
    .OUTPUTS
        None
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$args
    )
    cmd /c mklink $args 
}
