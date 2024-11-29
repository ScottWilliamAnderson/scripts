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
    .NOTES
        https://github.com/cli/cli#installation
    #>
    param (
        [Alias("f")]
        [switch]$Force
    )

    # Run the command
    gh copilot --version > $null

    # Check the exit code
    if ($LASTEXITCODE -eq 0) {
        # If $GH_PROFILE is not set, set it to the default value
        if (-not $GH_COPILOT_PROFILE) {
            $GH_COPILOT_PROFILE = Join-Path -Path $(Split-Path -Path $PROFILE -Parent) -ChildPath "gh-copilot.ps1"
        }
        # If the profile does not exist or the force flag is set, create the profile
        if ((-not (Test-Path $GH_COPILOT_PROFILE)) -or $Force) {
            gh copilot alias -- pwsh | Out-File ( New-Item -Path $GH_COPILOT_PROFILE -Force )
        }
        . $GH_COPILOT_PROFILE

    } else {
        Write-Output "Github Copilot is not installed. Skipping setup."
    }
}

# List of commands to run and their descriptions
$commands = @(
    @{ Verb = "Importing";
       Description = "Chocolatey Profile";
       Command = { Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1 } },
    @{ Verb = "Charging";
       Description = "Posh-Git";
       Command = { Import-Module posh-git } },
    @{ Verb = "Painting";
       Description = "Oh-My-Posh Theme";
       Command = { oh-my-posh init pwsh --config "$repoPath\oh-my-posh\plenty-of-info.omp.json" | Invoke-Expression } },
    @{ Verb = "Waking";
       Description = "Github Copilot";
       Command = { copilot-setup } },
    @{ Verb = "Refreshing";
       Description = "Environment Variables";
       Command = { refreshenv > $null } }
)

# Run each command and log timing if enabled
$total = $commands.Count
$counter = 0

# Define an array of "beep boop" animations
$beepBoopAnimations = @("[-. ] Beep boop   ", 
                        "[ o-] Beep boop.  ", 
                        "[-O ] Beep boop.. ", 
                        "[ o-] Beep boop...")

# Save the existing progress bar style
$existingView = $PSStyle.Progress.View

foreach ($cmd in $commands) {
    $counter++
    $percentComplete = ($counter / $total) * 100

    # Calculate the index for the animation frame
    $animationIndex = ($counter - 1) % $beepBoopAnimations.Count
    $activityText = $beepBoopAnimations[$animationIndex]

    Write-Progress -Activity $activityText -Status " $($cmd.Verb) $($cmd.Description)... " -PercentComplete $percentComplete

    $startTime = Get-Date
    & $cmd.Command
    $endTime = Get-Date

    if ($enableLogging) {
        Log-Timing -section $cmd.Description -startTime $startTime -endTime $endTime
    }
}

# Reset progress bar style to default
$PSStyle.Progress.View = $existingView


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
