# PowerShell Profile Setup Guide

## Introduction

This guide will help you set up your PowerShell profile to import a custom profile script from this repository. This setup will allow you to easily customize and synchronize your PowerShell environment across different machines.

## Prerequisites

- PowerShell 5.1 or later
- Git installed
- Oh My Posh installed
- Chocolatey installed
- Posh-Git installed

## Setup Instructions

1. **Clone the Repository**

   Clone this repository to your local machine:

   ```powershell
   git clone https://github.com/ScottWilliamAnderson/scripts.git
   ```

2. **Modify Your Main PowerShell Profile Script**

   Add the following code snippet to your main PowerShell profile script (e.g., `...\PowerShell\Microsoft.PowerShell_profile.ps1`):

   ```powershell
   # Check for required environment variables
   if (-not $env:USERPROFILE) {
       Write-Host "USERPROFILE environment variable is not set. Skipping profile import."
       return
   }

   # Define the path to the repository's profile script
   $repoPath = "$env:USERPROFILE\path\to\scripts\"

   # Define the path to the repository's profile script here and uncomment the following line
   # $repoPath = "$env:USERPROFILE\path\to\scripts\"

   # Check if the repository profile script exists
   if (Test-Path $repoPath) {
       $profilePath = "$repoPath\powershell-profile\profile.ps1"
       Write-Host "Importing profile from $profilePath"
       . $profilePath 
   } else {
       Write-Host "Repository profile script not found at $repoPath. Have you defined $repoPath in profile.ps1?"
   }
   ```

## Conclusion

By following these steps, you will have a customized PowerShell profile that can be easily synchronized across different environments. The autoupdate mechanism ensures that you always have the latest version of the profile script from the repository.

For more information, refer to the main repository [here](../README.md).
