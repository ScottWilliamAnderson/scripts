# GitHub Copilot Setup Script

function copilot-setup {
    <#
    .SYNOPSIS
        Sets up the GitHub Copilot CLI aliases (ghcs, ghce).
    .DESCRIPTION
        Generates and sources the gh-copilot.ps1 profile if GitHub CLI is installed.
        Note: This function should be called from the global scope (not from within
        another function) for the aliases to be available session-wide.
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

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Verbose "GitHub CLI (gh) is not installed. Skipping copilot setup."
        return
    }
    
    # If $GH_COPILOT_PROFILE is not set, set it to the default value
    if (-not $GH_COPILOT_PROFILE) {
        $GH_COPILOT_PROFILE = Join-Path -Path $(Split-Path -Path $PROFILE -Parent) -ChildPath "gh-copilot.ps1"
    }
    
    # If the profile does not exist or the force flag is set, create the profile
    if ((-not (Test-Path $GH_COPILOT_PROFILE)) -or $Force) {
        gh copilot alias -- pwsh | Out-File ( New-Item -Path $GH_COPILOT_PROFILE -Force )
    }
    
    # Source the copilot profile
    . $GH_COPILOT_PROFILE
}
