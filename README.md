# Utility Scripts Collection 🛠️

[![Last Commit](https://img.shields.io/github/last-commit/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Issues](https://img.shields.io/github/issues/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Stars](https://img.shields.io/github/stars/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![GitHub Forks](https://img.shields.io/github/forks/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)
[![Repository Size](https://img.shields.io/github/repo-size/ScottWilliamAnderson/scripts)](https://github.com/ScottWilliamAnderson/scripts)

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Python](https://img.shields.io/badge/Python-3.6+-green.svg)](https://www.python.org/)
[![Bash](https://img.shields.io/badge/Bash-4.0+-orange.svg)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A collection of useful scripts I've created or make use of.

## 📂 Available Scripts

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

## 🚀 Getting Started

1. Clone this repository
2. Navigate to the script folder you need
3. Check the README within each script folder for specific usage

## 🛠️ Contributing

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## 📝 License

MIT © Scott Anderson 2024
