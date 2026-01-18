# How often to re-verify git config (in days). Adjust this value if needed.
$script:gitConfigRefreshDays = 7

function setup-git {
    <#
    .SYNOPSIS
        Configures Git with useful defaults and aliases.
    .PARAMETER Force
        Forces re-configuration even if the sentinel file exists.
    .OUTPUTS
        None
    .NOTES
        Useful to run after installing Git, or if you want to sync your Git configuration across multiple machines.

        This function sets up the following:
        - Enables rerere
        - Enables columns in printed output
        - Sorts branches by last commit
        - Sets up aliases:
            - logs: Shows a pretty log with graph
            - unstage: Unstages a file
            - p: Adds files interactively
            - undo: Undoes the last commit
            - fpush: Force pushes with lease
            - publish: Pushes current branch with upstream setup

        A sentinel file (.git-config-done) is created after successful setup.
        The config is re-verified after $gitConfigRefreshDays days (default: 7).
        Delete the sentinel file or use -Force to re-run immediately.
    #>
    param (
        [switch]$Force
    )

    # Check if git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Skipping git setup."
        return
    }

    # Sentinel file to track if git config has been set up
    $sentinelPath = [System.IO.Path]::Combine($repoPath, ".git-config-done")

    # Skip if recently configured (unless -Force is specified)
    if (-not $Force -and [System.IO.File]::Exists($sentinelPath)) {
        $age = ([DateTime]::Now) - [System.IO.File]::GetLastWriteTime($sentinelPath)
        if ($age.TotalDays -lt $script:gitConfigRefreshDays) {
            Write-Verbose "Git config already set up (sentinel age: $([math]::Round($age.TotalDays, 1)) days)"
            return
        }
    }

    $settings = @(
        # Enable rerere
        @{ Key = "rerere.enabled"; Value = "true" },
        
        # Enable columns in output
        @{ Key = "column.ui"; Value = "auto" },
        
        # Sort branches by last commit
        @{ Key = "branch.sort"; Value = "-committerdate" },

        # Aliases
        # Pretty log with graph
        @{ Key = "alias.logs"; Value = "log --graph --pretty=format:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)- %an%Creset' --abbrev-commit" },
        
        # Unstage all files
        @{ Key = "alias.unstage"; Value = "reset HEAD --" },

        # Add files interactively
        @{ Key = "alias.p"; Value = "add --patch" },

        # Undo the last commit
        @{ Key = "alias.undo"; Value = "reset --soft HEAD~1" },

        # Force push with lease
        @{ Key = "alias.fpush"; Value = "push --force-with-lease" },

        # Push with setup upstream
        @{ Key = "alias.publish"; Value = '!git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)' }
    )

    foreach ($setting in $settings) {
        $currentValue = git config --global --get $setting.Key
        if ($currentValue -ne $setting.Value) {
            git config --global $setting.Key $setting.Value
        }
    }

    # Update sentinel file with current timestamp
    [System.IO.File]::WriteAllText($sentinelPath, ([DateTime]::Now).ToString("o"))
    Write-Verbose "Git config setup complete. Sentinel file updated: $sentinelPath"
}