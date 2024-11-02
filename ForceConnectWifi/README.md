# ForceConnectWiFi 🌐

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automatically force-connect to a specific WiFi network with configurable retry logic and status feedback.

## 📌 Features

- 🔄 Automatic retry mechanism
- ⚙️ Configurable retry attempts and intervals
- 📊 Visual connection status feedback
- ❌ Graceful error handling
- ⏱️ Auto-exit countdown

## 🚀 Usage

```powershell
.\ForceConnectWiFi.ps1 -networkName "<SSID>" [-maxRetries <1-100>] [-retryIntervalSeconds <1-300>]
```

### Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|--------|-------------|
| `networkName` | string | Required | - | WiFi network SSID to connect to |
| `maxRetries` | int | 5 | 1-100 | Maximum number of connection attempts |
| `retryIntervalSeconds` | int | 10 | 1-300 | Seconds between retry attempts |

### Examples

```powershell
# Basic usage
.\ForceConnectWiFi.ps1 -networkName "Office_WiFi"

# With custom retry settings
.\ForceConnectWiFi.ps1 -networkName "Home_Network" -maxRetries 10 -retryIntervalSeconds 5
```

## ⚙️ Requirements

- Windows 10/11
- PowerShell 5.1 or later
- WiFi adapter

## 🔍 Troubleshooting

1. Ensure WiFi adapter is enabled
2. Verify network name is correct
3. Check administrative privileges
4. Confirm network is in range

## 📝 License

MIT © Scott Anderson 2024

## 💡 Tips

- Use Task Scheduler to run at startup
- Create shortcut with parameters to add a shortcut on desktop
- Check Windows Event Viewer for detailed logs

---
*For more utilities, visit the main repository [here](../README.md)*