# PowerShell Profile Setup Guide 🖥️

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)

## 📚 Overview

A customized PowerShell profile with environment handling, package management, and productivity features.

This guide will help you set up your PowerShell profile to import a custom profile script from this repository.

## 📌 Features

- 🔄 Git-based auto-update mechanism
- 📦 Chocolatey integration (lazy-loaded for faster startup)
- 🎨 Oh My Posh theme support
- 🌿 Posh-Git integration (background-loaded)
- 🔑 Elevated privileges helper (sudo)
- 🌍 Environment variable management
- ⚡ **Optimized startup** with background loading (~1s to prompt)
- 💤 Sleep function to pause execution
- 🔗 Mklink function to create symbolic links
- ⏱️ Timing and logging for performance measurement
- 🤖 GitHub Copilot CLI integration
- 🔐 GPG agent auto-start for commit signing
- 🔔 Toast notifications with BurntToast (`notify` and `remind-me`)

## 🔍 Requirements

- PowerShell 5.1 or later
- Git installed
- Oh My Posh installed
- Chocolatey installed
- Posh-Git installed
- [BurntToast](https://github.com/Windos/BurntToast) installed

### Optional Requirements

- GitHub CLI (`gh`) installed
- GnuPG (`gpg`) installed with GPG signing configured in git

## 🚀 Setup Instructions

1. **Clone the Repository**

   Clone this repository to your local machine:

   ```powershell
   git clone https://github.com/ScottWilliamAnderson/scripts.git
   ```

2. **Modify Your Main PowerShell Profile Script**

   Add the following code snippet to your main PowerShell profile script (e.g., `...\PowerShell\Microsoft.PowerShell_profile.ps1`):

   You can open your main profile script by running:

   ```powershell
    notepad $PROFILE
    ```

    or

    ```powershell
    code $PROFILE
    ```

    Once the profile script is open, add the following code snippet:

   ```powershell
   # Check for required environment variables
   if (-not $env:USERPROFILE) {
       Write-Host "USERPROFILE environment variable is not set. Skipping profile import."
       return
   }

   # Define the path to the repository's profile script here and uncomment the following line
   # $repoPath = "$env:USERPROFILE\path\to\scripts"

   # Check if the repository profile script exists
   if (Test-Path $repoPath) {
       $profilePath = "$repoPath\powershell-profile\profile.ps1"
       Write-Host "Importing profile from $profilePath"
       . $profilePath 
   } else {
       Write-Host "Repository profile script not found at $repoPath. Have you defined $repoPath in profile.ps1?"
   }
   ```

3. **Customize the Repository Path**

   Uncomment the `$repoPath` variable in the code snippet and set it to the path where you cloned the repository.

   For example:

   ```powershell
   $repoPath = "$env:USERPROFILE\Documents\GitHub\scripts"
   ```

## ⚙️ Available Commands

| Command | Description |
|---------|------------|
| `pull-profile` | Updates profile from Git repository |
| `sudo` | Opens elevated Windows Terminal |
| `refreshenv` | Refreshes environment variables |
| `choco` | Chocolatey package manager |
| `posh-git` | Posh-Git integration |
| `oh-my-posh` | Oh My Posh theme support |
| `$PROFILE` | Path to the current profile script |
| `sleep` | Pauses execution for a specified number of seconds |
| `mklink` | Creates symbolic links |
| `copilot-setup` | Configures GitHub Copilot CLI to use `ghcs` and `ghce` aliases |
| `start-gpg-agent` | Starts the GPG agent if GPG signing is configured |
| `vlcs`   | Quickly activates the VLC speedup AutoHotkey script (`vlc-speed-controls.ahk`) from anywhere |
| `notify` | Displays a Windows toast notification using BurntToast |
| `remind-me` | Sets a timer-based reminder notification (e.g., `remind-me 5m "Take a break"`) |
| `Initialize-Opencode` | One-time setup or migration of the OpenShell gateway to run under the non-root WSL user, with autostart at WSL boot. Idempotent. |
| `Start-Opencode` | Launches [opencode](https://opencode.ai) inside an OpenShell sandbox in WSL, port-forwards the web UI to Windows, opens browser. See [StartOpencode/README.md](../StartOpencode/README.md). |
| `Stop-Opencode` | Stops opencode web in a sandbox and removes the port forward. Idempotent. |
| `Show-OpencodeLogs` | Tails the opencode web log inside a sandbox (Ctrl-C to exit). `-NoFollow` to print last N lines and exit. |
| `Get-OpencodeStatus` | One-page overview of the Opencode setup: gateway, sandboxes (phase + opencode-web running? + project dirs), port forwards. |
| `Set-OpencodeEgress` | Hot-add (`-Allow github.com,pypi.org,...`) or remove (`-Deny ...`) outbound domains on a running sandbox; each entry covers the apex and `*.apex`. |

## ⏱️ Startup Performance

The profile is optimized for fast startup using a multi-phase loading approach:

| Phase | What Loads | Blocking? | Time |
|-------|------------|-----------|------|
| 1. Blocking | Oh-My-Posh, GitHub Copilot | Yes | ~500-700ms |
| 2. Background | Git config, GPG agent, Posh-Git | No | ~1-2s |
| 3. Lazy | Chocolatey (on first `refreshenv`) | No | ~250ms |

**Result:** Prompt appears in ~1-1.3s, full features available after ~2s.


### Git Config Sentinel

The git configuration (`setup-git`) uses a sentinel file to avoid re-running every startup:

- **Location:** `.git-config-done` in the repository root
- **Refresh interval:** Every 7 days (configurable via `$gitConfigRefreshDays`)
- **Force refresh:** Run `setup-git -Force` or delete the sentinel file

## ⏱️ Timing and Logging

The profile script now includes timing and logging functionality to measure the performance of each section. Timing information is logged to a file named `profile_timing.log` in the `powershell-profile` directory. The log file records the start time, end time, and duration for each section of the profile script.

## 📝 Optional Logging

Logging is optional and controlled by the `ENABLE_PROFILE_LOGGING` environment variable. By default, logging is disabled. To enable logging, set the `ENABLE_PROFILE_LOGGING` environment variable to `true`.

For more information, refer to the main repository [here](../README.md).
