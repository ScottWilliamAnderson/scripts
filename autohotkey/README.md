# VLC AutoHotkey Speed Controls 🎮

<img alt="AutoHotkey" src="https://img.shields.io/badge/AutoHotkey-1.x-green.svg">
<img alt="VLC" src="https://img.shields.io/badge/VLC-3.0+-orange.svg">
<img alt="Platform" src="https://img.shields.io/badge/Platform-Windows-blue.svg">
<img alt="MIT License" src="https://img.shields.io/badge/License-MIT-yellow.svg">


A convenient AutoHotkey script for controlling VLC media player playback speed using keyboard shortcuts.

## 📌 Features
- 🎯 Instant speed control with number keys
- ⚡ Press and hold functionality
- 🔄 Auto-reset on key release
- 🎮 VLC-specific activation
- ⌨️ Customizable speed presets

## 🔍 Requirements
- Windows 10/11
- AutoHotkey v1.x
- VLC Media Player 3.0+

## 🚀 Installation

### Install AutoHotkey

```powershell
# Using Chocolatey
choco install autohotkey vlc
```
OR

Download from [autohotkey.com](https://www.autohotkey.com/)
Run installer with default options


### Download Script

Clone this repository or download directly:
```powershell 
git clone https://github.com/ScottWilliamAnderson/scripts.git 
cd scripts/autohotkey
```

### Run Script

Double-click vlc-speed-controls.ahk

Or from PowerShell:

```powershell 
Start-Process "vlc-speed-controls.ahk"
```

## 🎮 Usage

| Key | Action         | Release Action |
|-----|----------------|----------------|
| 1   | Set 1.5x speed | Return to 1.0x |
| 2   | Set 2.0x speed | Return to 1.0x |
| 3   | Set 3.0x speed | Return to 1.0x |
| 4   | Set 4.0x speed | Return to 1.0x |
| 5   | Set 5.0x speed | Return to 1.0x |

## 🔧 Configuration
Edit vlc-speed-controls.ahk to customize:

- Speed presets
- Key bindings
- Reset behaviour

## 🔍 Troubleshooting
*Script not working*

1. Ensure VLC window is active
2. Check AutoHotkey is running (system tray)
3. Run as administrator if needed


*Speed not changing*

1. Verify VLC version compatibility
2. Check for conflicting keyboard shortcuts

## 📝 License
MIT © Scott Anderson 2024

*For more utilities, visit the main repository [here](../README.md)*