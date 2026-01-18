# Git Configuration Script 🌿

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Git](https://img.shields.io/badge/Git-2.0+-orange.svg)](https://git-scm.com/)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automatically configures Git with useful defaults and aliases for improved productivity and consistent development workflows.

## 📌 Features

Adds a `setup-git` function to configure Git with the following settings:

- 🔄 Enables Git rerere (reuse recorded resolution) for merge conflict handling
- 📊 Enables column output for better readability
- 📅 Sorts branches by last commit date
- 🔒 Safe defaults for push/pull behavior
- ⚡ Sets up useful aliases:
  - logs: Pretty log with branch graph
  - unstage: Unstages files
  - p: Interactive patch mode
  - undo: Undoes last commit
  - fpush: Force push with lease
  - publish: Pushes current branch with upstream setup

## 🚀 Usage

Import and run the setup function:

```powershell
. .\git-config\git-config.ps1
setup-git
```

### Automatic Setup (Profile Integration)

When using the PowerShell profile from this repository, `setup-git` runs automatically in the background during startup. A **sentinel file** (`.git-config-done`) is created after successful setup to avoid re-running on every startup.

- The configuration is re-verified automatically every **7 days**
- To force immediate re-configuration: `setup-git -Force`
- To change the refresh interval, modify `$gitConfigRefreshDays` in `git-config.ps1`
- To manually trigger a refresh, delete `.git-config-done` from the repository root

### Included Aliases & Configurations

| Setting | Value | Description |
|---------|-------|-------------|
| rerere.enabled | true | Remembers merge conflict resolutions |
| column.ui | auto | Enables columnar output |
| branch.sort | -committerdate | Sorts branches by recent commits |
| logs | log --graph --pretty=... | Shows commit history with branch graph |
| unstage | reset HEAD -- | Removes files from staging area |
| p | add --patch | Interactively stage changes |
| undo | reset --soft HEAD~1 | Undoes last commit, preserving changes |
| fpush | push --force-with-lease | Safer force push |
| publish | !git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD) | Pushes current branch with upstream setup |

## ⚙️ Requirements

- Git 2.0+
- PowerShell 5.1+

## 🔍 Troubleshooting

1. Ensure Git is installed and accessible from PowerShell
2. Run PowerShell with administrator privileges if needed
3. Check git config --list to verify settings

## 📝 License

MIT © Scott Anderson 2024

---
*For more utilities, visit the main repository [here](../README.md)*