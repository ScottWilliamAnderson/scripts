function setup-git {
    <#
    .SYNOPSIS
        Configures Git with useful defaults and aliases.
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
    #>
    # Check if git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Skipping git setup."
        return
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
        @{ Key = "alias.fpush"; Value = "push --force-with-lease" }
    )

    foreach ($setting in $settings) {
        $currentValue = git config --global --get $setting.Key
        if ($currentValue -ne $setting.Value) {
            git config --global $setting.Key $setting.Value
        }
    }

}