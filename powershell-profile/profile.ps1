# PowerShell Profile Script

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

# Import the logging script
$t1 = [DateTime]::Now
. "$PSScriptRoot\logging.ps1"
if ($enableLogging) { Log-Timing -section "Import logging.ps1" -startTime $t1 -endTime ([DateTime]::Now) }

# Check PSReadLine history file size (large files can cause 30+ second startup delays)
$historyPath = [System.IO.Path]::Combine($env:APPDATA, "Microsoft", "Windows", "PowerShell", "PSReadLine", "ConsoleHost_history.txt")
if ([System.IO.File]::Exists($historyPath)) {
    $historySize = (New-Object System.IO.FileInfo $historyPath).Length
    $historySizeMB = [math]::Round($historySize / 1MB, 1)
    if ($historySize -gt 50MB) {
        Write-Warning "PSReadLine history file is $historySizeMB MB. Large history files can slow startup."
        Write-Warning "Consider running: Set-PSReadLineOption -MaximumHistoryCount 10000"
        Write-Warning "Or manually trim: $historyPath"
    }
}

# Import the git config script
$t2 = [DateTime]::Now
. "$repoPath\git-config\git-config.ps1"
if ($enableLogging) { Log-Timing -section "Import git-config.ps1" -startTime $t2 -endTime ([DateTime]::Now) }

# Import the copilot-setup script
$t3 = [DateTime]::Now
. "$PSScriptRoot\copilot-setup.ps1"
if ($enableLogging) { Log-Timing -section "Import copilot-setup.ps1" -startTime $t3 -endTime ([DateTime]::Now) }

# Import the gpg-setup script
$t4 = [DateTime]::Now
. "$PSScriptRoot\gpg-setup.ps1"
if ($enableLogging) { Log-Timing -section "Import gpg-setup.ps1" -startTime $t4 -endTime ([DateTime]::Now) }

# Import the commands script (this runs Oh-My-Posh and sets up deferred loading)
$t5 = [DateTime]::Now
. "$PSScriptRoot\commands.ps1"
if ($enableLogging) { Log-Timing -section "Import commands.ps1" -startTime $t5 -endTime ([DateTime]::Now) }

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

# Activate the vlc speedup autohotkey script
function vlcs {
    <#
    .SYNOPSIS
        Activates the VLC speedup autohotkey script.
    .OUTPUTS
        None
    #>

    Write-Host "Activating VLC speedup autohotkey script..."

    . "$repoPath\autohotkey\vlc-speed-controls.ahk"
}