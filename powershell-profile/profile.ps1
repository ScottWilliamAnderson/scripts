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

# Toast notification using BurntToast
function notify {
    <#
    .SYNOPSIS
        Displays a Windows toast notification using BurntToast.
    .DESCRIPTION
        A simple wrapper around New-BurntToastNotification for quick notifications.
        Useful for alerting when long-running scripts complete.
    .PARAMETER Message
        The notification body text.
    .PARAMETER Title
        Optional notification title.
    .PARAMETER Sound
        Notification sound. Common values: Default, IM, Mail, Reminder, SMS, Alarm, 
        Alarm2-10, Call, Call2-10. Custom values are also accepted.
    .PARAMETER Urgent
        Mark the notification as important/urgent.
    .PARAMETER Image
        Custom icon/image path for the notification.
    .EXAMPLE
        notify "Build complete!"
    .EXAMPLE
        notify "Build complete!" -Title "npm build"
    .EXAMPLE
        notify "Deployment finished" -Title "Deploy" -Sound Alarm -Urgent
    .EXAMPLE
        npm run build && notify "Build succeeded!" -Title "npm" || notify "Build FAILED!" -Title "npm" -Urgent -Sound Alarm
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Notification body text")]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            @('Default', 'IM', 'Mail', 'Reminder', 'SMS', 'Alarm', 'Alarm2', 'Alarm3', 'Alarm4', 'Alarm5',
              'Alarm6', 'Alarm7', 'Alarm8', 'Alarm9', 'Alarm10', 'Call', 'Call2', 'Call3', 'Call4', 'Call5',
              'Call6', 'Call7', 'Call8', 'Call9', 'Call10') | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Sound,

        [Parameter(Mandatory = $false)]
        [switch]$Urgent,

        [Parameter(Mandatory = $false)]
        [string]$Image
    )

    # Check if BurntToast module is available
    if (-not (Get-Module -ListAvailable -Name BurntToast)) {
        Write-Error "BurntToast module is not installed. Install it with: Install-Module -Name BurntToast -Scope CurrentUser"
        return
    }

    # Import BurntToast if not already loaded
    if (-not (Get-Module -Name BurntToast)) {
        Import-Module BurntToast -ErrorAction Stop
    }

    # Build parameters hashtable
    $params = @{
        Text = $Message
    }

    if ($Title) {
        $params.Text = $Title, $Message
    }

    if ($Sound) {
        $params.Sound = $Sound
    }

    if ($Urgent) {
        $params.Urgent = $true
    }

    if ($Image) {
        $params.AppLogo = $Image
    }

    try {
        New-BurntToastNotification @params
    }
    catch {
        Write-Error "Failed to send notification: $_"
    }
}

# Timer-based reminder notification
function remind-me {
    <#
    .SYNOPSIS
        Sets a timer-based reminder that sends a toast notification after a delay.
    .DESCRIPTION
        Schedules a reminder notification after a specified time delay.
        Supports time formats like 5s (seconds), 5m (minutes), 1h (hours).
    .PARAMETER Delay
        Time delay before showing the notification (e.g., 5s, 5m, 1h, 30s).
    .PARAMETER Message
        The reminder message to display.
    .EXAMPLE
        remind-me 5m "Take a break"
    .EXAMPLE
        remind-me 1h "Check on deployment"
    .EXAMPLE
        remind-me 30s "Timer done"
    .EXAMPLE
        remind-me 25m "Pomodoro break"
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Time delay (e.g., 5s, 5m, 1h)")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^(\d+)(s|m|h)$')]
        [string]$Delay,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Reminder message")]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    # Check if BurntToast module is available before starting the timer
    if (-not (Get-Module -ListAvailable -Name BurntToast)) {
        Write-Error "BurntToast module is not installed. Install it with: Install-Module -Name BurntToast -Scope CurrentUser"
        return
    }

    # ValidatePattern ensures this match always succeeds;
    # we run it here only to populate the $Matches automatic variable.
    $null = $Delay -match '^(\d+)(s|m|h)$'

    $value = [int]$Matches[1]
    $unit = $Matches[2]

    $seconds = switch ($unit) {
        's' { $value }
        'm' { $value * 60 }
        'h' { $value * 3600 }
    }

    # Calculate the reminder time for display
    $reminderTime = (Get-Date).AddSeconds($seconds).ToString("HH:mm:ss")

    Write-Host "Reminder set for $reminderTime ($Delay from now): $Message"

    # Script block for the reminder job
    $reminderScript = {
        param($seconds, $message)
        
        Start-Sleep -Seconds $seconds
        
        # Import BurntToast in the job context with error handling
        try {
            Import-Module BurntToast -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to import BurntToast module in reminder job: $($_.Exception.Message)"
            return
        }
        
        try {
            New-BurntToastNotification -Text "Reminder", $message -Sound Reminder -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to send reminder notification: $($_.Exception.Message)"
        }
    }

    # Use Start-ThreadJob if available (auto-cleans up), otherwise fall back to Start-Job
    if (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue) {
        $job = Start-ThreadJob -ScriptBlock $reminderScript -ArgumentList $seconds, $Message
        
        # Register cleanup event for when the job completes
        $null = Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
            if ($Event.Sender.State -in @("Completed", "Failed", "Stopped")) {
                Remove-Job -Job $Event.Sender -Force -ErrorAction SilentlyContinue
                Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -ErrorAction SilentlyContinue
            }
        } -SupportEvent
    }
    else {
        # Fallback to Start-Job with cleanup after completion
        $job = Start-Job -ScriptBlock $reminderScript -ArgumentList $seconds, $Message
        
        # Register cleanup event for when the job completes
        $null = Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
            if ($Event.Sender.State -in @("Completed", "Failed", "Stopped")) {
                Remove-Job -Job $Event.Sender -Force -ErrorAction SilentlyContinue
                Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -ErrorAction SilentlyContinue
            }
        } -SupportEvent
    }
}