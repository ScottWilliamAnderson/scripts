# AutoHotkey Scripts 🎮

<img alt="AutoHotkey" src="https://img.shields.io/badge/AutoHotkey-1.x-green.svg">
<img alt="Platform" src="https://img.shields.io/badge/Platform-Windows-blue.svg">
<img alt="MIT License" src="https://img.shields.io/badge/License-MIT-yellow.svg">

A collection of AutoHotkey scripts for enhancing application controls on Windows.

## 🔍 Requirements
- Windows 10/11
- AutoHotkey v1.x

## 🚀 Installation

### Install AutoHotkey

```powershell
# Using Chocolatey
choco install autohotkey
```
OR

Download from [autohotkey.com](https://www.autohotkey.com/)
Run installer with default options


### Download Scripts

Clone this repository or download directly:
```powershell 
git clone https://github.com/ScottWilliamAnderson/scripts.git 
cd scripts/autohotkey
```

### Running Scripts

Double-click any `.ahk` file to run it. A green "H" icon will appear in the system tray indicating the script is active.

To run on Windows startup:
1. Press `Win + R`, type `shell:startup`, and press Enter
2. Create a shortcut to the desired `.ahk` file in this folder

---

## 📜 Available Scripts

### Minecraft Hotbar Scroll

**File:** `MinecraftHotbarScroll.ahk`

Remaps mouse side buttons to scroll the Minecraft hotbar, allowing you to switch hotbar slots without moving your hand to the scroll wheel.

#### 📌 Features
- 🎯 Mouse side button control for hotbar
- ⚡ Works with Shift held (for stack splitting)
- 🎮 Minecraft Java Edition only (detects `javaw.exe`)

#### 🎮 Usage

| Button | Action |
|--------|--------|
| XButton1 (Back) | Scroll hotbar right (next slot) |
| XButton2 (Forward) | Scroll hotbar left (previous slot) |

#### 🔧 Notes
- The script activates only when Minecraft (Java Edition) is the active window
- Uses `{Blind}` modifier to preserve modifier key states (e.g., holding Shift)

---

### VLC Speed Controls

**File:** `vlc-speed-controls.ahk`

<img alt="VLC" src="https://img.shields.io/badge/VLC-3.0+-orange.svg">

A convenient script for controlling VLC media player playback speed using keyboard shortcuts.

#### 📌 Features
- 🎯 Instant speed control with number keys
- ⚡ Press and hold functionality
- 🔄 Auto-reset on key release
- 🎮 VLC-specific activation

#### 🔍 Additional Requirements
- VLC Media Player 3.0+

#### 🎮 Usage

| Key | Action         | Release Action |
|-----|----------------|----------------|
| 1   | Set 1.5x speed | Return to 1.0x |
| 2   | Set 2.0x speed | Return to 1.0x |
| 3   | Set 3.0x speed | Return to 1.0x |
| 4   | Set 4.0x speed | Return to 1.0x |
| 5   | Set 5.0x speed | Return to 1.0x |

#### 🔧 Configuration
Edit `vlc-speed-controls.ahk` to customize:

- Speed presets
- Key bindings
- Reset behaviour

#### 💡 Tip
If you have the updated `profile.ps1` with the `vlcs` function, simply type:
```powershell
vlcs
```
This will launch `vlc-speed-controls.ahk` automatically.

---

## 🔍 Troubleshooting

*Script not working*

1. Ensure the target application window is active
2. Check AutoHotkey is running (green "H" in system tray)
3. Run as administrator if needed

*Hotkeys not triggering*

1. Verify application compatibility (check window title/exe name)
2. Check for conflicting keyboard/mouse shortcuts
3. Ensure AutoHotkey v1.x is installed (not v2.x)

## 📝 License
MIT © Scott Anderson 2025

*For more utilities, visit the main repository [here](../README.md)*
