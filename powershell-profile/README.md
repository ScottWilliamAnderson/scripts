# PowerShell Profile Setup Guide 🖥️

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)

## 📚 Overview

A customized PowerShell profile with environment handling, package management, and productivity features.

This guide will help you set up your PowerShell profile to import a custom profile script from this repository. 

## 📌 Features

- 🔄 Git-based auto-update mechanism
- 📦 Chocolatey integration
- 🎨 Oh My Posh theme support
- 🌿 Posh-Git integration
- 🔑 Elevated privileges helper (sudo)
- 🌍 Environment variable management
- ⚡ Performance optimizations
- 💤 Sleep function to pause execution
- 🔗 Mklink function to create symbolic links

## 🔍 Requirements

- PowerShell 5.1 or later
- Git installed
- Oh My Posh installed
- Chocolatey installed
- Posh-Git installed

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

For more information, refer to the main repository [here](../README.md).
