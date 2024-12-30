# Utility Scripts Collection 🛠️

[![Last Commit](https://img.shields.io/github/last-commit/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Issues](https://img.shields.io/github/issues/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Stars](https://img.shields.io/github/stars/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Forks](https://img.shields.io/github/forks/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![Repository Size](https://img.shields.io/github/repo-size/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Bash](https://img.shields.io/badge/Bash-4.0+-orange.svg)](https://www.gnu.org/software/bash/)
[![Git](https://img.shields.io/badge/Git-2.0+-green.svg)](https://git-scm.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A collection of useful scripts I've created, or make use of.

## 📂 Available Scripts

### Development Tools
- [**git-config**](git-config/README.md) (PowerShell) - Automated Git configuration with productivity-focused defaults

```powershell
. .\git-config\git-config.ps1
setup-git
```

### Network Utilities
- [**ForceConnectWiFi**](ForceConnectWifi/README.md) (PowerShell) - WiFi connection manager with retry capabilities
```powershell
.\ForceConnectWiFi\ForceConnectWiFi.ps1 -networkName "Your_Network_Name" -maxRetries 5 -retryIntervalSeconds 10
```

### Shell Customisations
- [**plenty-of-info**](oh-my-posh/README.md) (Oh My Posh Theme) - Unintrusive theme with plenty of system, environment information
```powershell
oh-my-posh init pwsh --config 'path/to/plenty-of-info.omp.json' | Invoke-Expression
```

- [**profile.ps1**](powershell-profile/README.md) (PowerShell) - Custom PowerShell profile script with environment handling, autoupdate mechanism, and additional features. See the [README](powershell-profile/README.md) for the full list of features and how to install.
```powershell
# Check for required environment variables
if (-not $env:USERPROFILE) {
    Write-Host "USERPROFILE environment variable is not set. Skipping profile import."
    return
}

# Define the path to the repository's profile script here
$repoPath = "$env:USERPROFILE\path\to\scripts\"

# Check if the repository profile script exists
if (Test-Path $repoPath) {
    $profilePath = "$repoPath\powershell-profile\profile.ps1"
    Write-Host "Importing profile from $profilePath"
    . $profilePath 
} else {
    Write-Host "Repository profile script not found at $repoPath"
}
```

### Chocolatey
- [**packages.config**](chocolatey/README.md) (Chocolatey) - List of installed Chocolatey packages
```powershell
choco install packages.config
```

### AutoHotkey Scripts
- [**vlc-autohotkey**](autohotkey/README.md) (AutoHotkey) - Quick speed controls for VLC
```powershell
# Manually:
cd .\autohotkey\
.\vlc-speed-controls.ahk

# via PowerShell alias/function:
vlcs
# Instantly launches the script thanks to a function in profile.ps1
```

## 🚀 Getting Started

1. Clone this repository:

```bash
git clone https://github.com/ScottWilliamAnderson/scripts.git
```

2. Navigate to desired script folder:

```bash
cd scripts/<script-folder>
```

3. Check individual README files for detailed usage instructions

## 🛠️ Contributing

1. Fork the repository
2. Create your feature branch
3. Follow the [contribution guidelines](.github/CONTRIBUTING.md)
4. Submit a pull request

## 🔍 Requirements

- Windows 10/11
- PowerShell 5.1+
- Git 2.0+
- [Optional] Chocolatey package manager
- [Optional] Oh My Posh
- [Optional] GitHub CLI
- [Optional] AutoHotkey

## 📝 License

MIT © Scott Anderson 2024
