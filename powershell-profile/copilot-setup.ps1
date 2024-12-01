# GitHub Copilot Setup Script

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

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Output "Github Copilot is not installed. Skipping ghcs setup."
        return
    }
    
    # If $GH_PROFILE is not set, set it to the default value
    if (-not $GH_COPILOT_PROFILE) {
        $GH_COPILOT_PROFILE = Join-Path -Path $(Split-Path -Path $PROFILE -Parent) -ChildPath "gh-copilot.ps1"
    }
    # If the profile does not exist or the force flag is set, create the profile
    if ((-not (Test-Path $GH_COPILOT_PROFILE)) -or $Force) {
        gh copilot alias -- pwsh | Out-File ( New-Item -Path $GH_COPILOT_PROFILE -Force )
    }
    . $GH_COPILOT_PROFILE
    
}
