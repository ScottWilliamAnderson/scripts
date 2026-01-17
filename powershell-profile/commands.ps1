# Command List and Execution Script

# List of commands to run and their descriptions
$commands = @(
    @{ Verb = "Importing";
       Description = "Chocolatey Profile";
       Command = { Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1 } },
    @{ Verb = "Growing";
       Description = "Git Config";
       Command = { setup-git } },
    @{ Verb = "Charging";
       Description = "Posh-Git";
       Command = { Import-Module posh-git } },
    @{ Verb = "Painting";
       Description = "Oh-My-Posh Theme";
       Command = { oh-my-posh init pwsh --config "$repoPath\oh-my-posh\plenty-of-info.omp.json" | Invoke-Expression } },
    @{ Verb = "Waking";
       Description = "Github Copilot";
       Command = { copilot-setup } },
    @{ Verb = "Unlocking";
       Description = "GPG Agent";
       Command = { Start-GpgAgent } },
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
