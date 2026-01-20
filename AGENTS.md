# AGENTS.md - Guidelines for AI Coding Agents

This file provides instructions for AI coding agents working in this repository.

## Project Overview

A collection of Windows utility scripts for personal productivity and system management:

- **PowerShell scripts** (primary) - Profile customization, git config, WiFi utilities
- **AutoHotkey scripts** (v1.x) - Keyboard automation for applications like VLC
- **Configuration files** - Oh My Posh themes, Chocolatey packages

**Target Platform:** Windows 10/11 only

## Build/Lint/Test Commands

This is a scripts collection, not a compiled application. No build system or test framework.

### Running Scripts

```powershell
.\ForceConnectWifi\ForceConnectWiFi.ps1 -networkName "MyNetwork_5G"
.\ForceConnectWifi\ForceConnectWiFi.ps1 -networkName "MyNetwork" -Verbose
```

### Testing

- Manual testing on Windows 10/11 is required
- Test scripts in a PowerShell 5.1+ environment
- AutoHotkey scripts require AutoHotkey v1.x installed

## Code Style Guidelines

### General Formatting

- **Indentation:** 4 spaces (no tabs)
- **File encoding:** UTF-8

### PowerShell Scripts

#### Comment-Based Help (Required for all functions)

```powershell
function Get-Example {
    <#
    .SYNOPSIS
        Brief description of what the function does.
    .PARAMETER Name
        Description of the parameter.
    .EXAMPLE
        Get-Example -Name "test"
    .OUTPUTS
        Return type description
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    # Implementation
}
```

#### Script-Level Help (Required for standalone scripts)

```powershell
<#
.SYNOPSIS
    Brief description of the script.
.PARAMETER paramName
    Description of parameters.
.EXAMPLE
    .\Script.ps1 -paramName "value"
.NOTES
    File Name      : Script.ps1
    Prerequisite   : PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$paramName
)
```

#### Parameter Validation

```powershell
[Parameter(Mandatory = $true, Position = 0, HelpMessage = "Description")]
[ValidateNotNullOrEmpty()]
[ValidateRange(1, 100)]
[ValidateSet("Option1", "Option2")]
[string]$ParameterName
```

#### Error Handling

```powershell
try {
    $result = Some-Operation
}
catch {
    Write-Error "Failed to perform operation: $_"
    return $false
}
```

#### Naming Conventions

- **Functions:** Use `Verb-Noun` format (e.g., `Connect-Network`, `Test-NetworkConnection`)
- **Variables:** Use `$camelCase` for local variables
- **Parameters:** Use `$PascalCase` for parameters

#### Output and Logging

- Use `Write-Host` for user-facing output
- Use `Write-Verbose` for debug/detailed information
- Use `Write-Error` for error messages

### AutoHotkey Scripts (v1.x)

```autohotkey
#NoEnv                   ; Recommended for performance
SendMode Input           ; Faster, more reliable
SetWorkingDir %A_ScriptDir%

; --- Description of hotkey block ---
$*HotkeyKey::
    ; Action
    KeyWait, HotkeyKey
return
```

## Commit Message Guidelines

This project uses [Conventional Commits](https://www.conventionalcommits.org/) style.

### Format

```
<type>(<scope>): <description>

[optional body]
```

- **Subject line:** 50 characters max, lowercase, imperative mood, no period
- **Body:** Wrap at 72 characters, explain "why" not "how"
- **Scope:** Optional, indicates the area of the codebase (e.g., `autohotkey`, `profile`, `git-config`)

### Types

- `feat` - New feature or script
- `fix` - Bug fix
- `docs` - Documentation only changes
- `refactor` - Code restructuring without behavior change
- `chore` - Maintenance tasks, dependencies, configs

### Commit Strategy

- **Prefer small, targeted commits** over large feature commits
- Each commit should represent a single logical change
- When adding a feature, consider separate commits for:
  - The core implementation
  - Documentation updates
  - README updates
- Use `git add -p` to stage hunks when a file contains multiple logical changes

## Adding New Scripts

1. Create a new folder for your script category
2. Include a `README.md` with features, requirements, installation, usage, troubleshooting
3. Add entry to main `README.md`
4. Ensure script is well-documented with comment-based help

## Dependencies

- **PowerShell 5.1+** (comes with Windows 10/11)
- **Git** - For git-config and profile update features
- **Oh My Posh** - Terminal prompt theming
- **Posh-Git** - Git integration for PowerShell
- **Chocolatey** - Windows package manager
- **AutoHotkey v1.x** - For .ahk scripts
- **GitHub CLI (gh)** - Optional, for Copilot integration

## Important Notes for Agents

1. **Always test on Windows** - These scripts are Windows-specific
2. **Preserve existing patterns** - Follow the code style in existing files
3. **Document everything** - Every function needs comment-based help
4. **Update READMEs** - When modifying scripts, update their README.md
5. **No build step required** - Scripts run directly
6. **PowerShell execution policy** - Users may need to set execution policy
