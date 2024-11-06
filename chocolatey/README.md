# Chocolatey Packages List 📦

[![Chocolatey](https://img.shields.io/badge/Chocolatey-0.10.15+-blue.svg)](https://chocolatey.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A list of installed Chocolatey packages for easy reinstallation and sharing.

## 📌 Features

- 📦 List of installed Chocolatey packages
- 🔄 Easy reinstallation of packages
- 📤 Export and share package list

## 🚀 Usage

### Export Installed Packages

To export the list of installed Chocolatey packages to `packages.config`:

```powershell
choco export -o packages.config
```

### Install Packages from `packages.config`

To install the packages listed in `packages.config`:

```powershell
choco install packages.config
```

## 📝 License

MIT © Scott Anderson 2024

---
*For more utilities, visit the main repository [here](../README.md)*
