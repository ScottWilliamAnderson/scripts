<#
.SYNOPSIS
    Refresh the Pi config backup without credentials or runtime data.
.PARAMETER AgentPath
    Pi agent directory to copy from.
.EXAMPLE
    .\pi\setup.ps1
.NOTES
    Requires PowerShell 5.1+. Review custom files for secrets before committing.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$AgentPath = "$env:USERPROFILE\.pi\agent"
)
$ErrorActionPreference = 'Stop'
$destination = Join-Path $PSScriptRoot 'agent'
# Only reusable config and user-authored resources; never copy whole agent state.
$paths = @(
    'AGENTS.md', 'settings.json', 'keybindings.json', 'fusion.json',
    'pi-chrome-devtools.json', 'pi-statusline.json', 'pi-stamp.json',
    'pi-file-context.json', 'pi-lsp.json',
    'agents', 'skills', 'prompts', 'themes', 'patches'
)
foreach ($item in $paths) {
    $source = Join-Path $AgentPath $item
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
}
# Changelog acknowledgement is runtime state, not a preference.
$settingsPath = Join-Path $destination 'settings.json'
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$settings.PSObject.Properties.Remove('lastChangelogVersion')
$settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
# Herdr maintains its own extension. Keep only our two custom extensions.
foreach ($item in @('edit-file.ts', 'session-background.ts')) {
    $source = Join-Path $AgentPath "extensions\$item"
    Copy-Item -LiteralPath $source -Destination (Join-Path $destination 'extensions') -Force
}
Write-Host 'Pi config copied. Review before committing; remove retired files explicitly.'
