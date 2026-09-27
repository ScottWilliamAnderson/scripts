# Neovim (LazyVim) Config 📝

[![Neovim](https://img.shields.io/badge/Neovim-0.11.2+-green.svg)](https://neovim.io/)
[![LazyVim](https://img.shields.io/badge/LazyVim-starter-blue.svg)](https://www.lazyvim.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)

My [LazyVim](https://www.lazyvim.org/) config, shared between machines by linking `%LOCALAPPDATA%\nvim` to this folder.

## 📌 Features

- ☕ **Java** - `lang.java` extra (jdtls via [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls))
- 🐍 **Python** - `lang.python` extra using [ty](https://github.com/astral-sh/ty) + [ruff](https://github.com/astral-sh/ruff)
- 💻 **PowerShell 7** for the built-in terminal (`Ctrl+/`) and `:!` commands
- 🔒 `lazy-lock.json` pins the same plugin versions on every machine

Language servers, linters and formatters are installed by [Mason](https://github.com/mason-org/mason.nvim) into `%LOCALAPPDATA%\nvim-data\mason`, not onto the system `PATH`.

## 🔧 Requirements

- [Chocolatey](https://chocolatey.org/) (admin PowerShell)
- [uv](https://docs.astral.sh/uv/) - provides the `python` that Mason and jdtls need
- Java 21+ on `PATH` - only needed for Java files
- A terminal with true colour and undercurl, e.g. Windows Terminal

## 📥 Installation

1. Install the tools in an admin PowerShell:

```powershell
choco install neovim git ripgrep fzf fd lazygit tree-sitter mingw nerd-fonts-Meslo -y
```

| Package | Why |
|---|---|
| `neovim` | The editor |
| `git` | lazy.nvim installs plugins with git |
| `ripgrep`, `fzf`, `fd` | Searching files and text (`Space /`, `Space Space`) |
| `lazygit` | Git UI (`Space g g`) |
| `tree-sitter`, `mingw` | CLI + C compiler to build syntax-highlighting parsers |
| `nerd-fonts-Meslo` | Icons |

2. Give Mason and jdtls a `python` (uv-managed, adds shims to `~\.local\bin`):

```powershell
uv python install 3.12 --default
```

3. Set the Windows Terminal font to **MesloLGM Nerd Font** (Settings → your profile → Appearance → Font face).

4. Link this folder as the Neovim config (a junction needs no admin). Back up any existing config first:

```powershell
if (Test-Path "$env:LOCALAPPDATA\nvim") { Move-Item "$env:LOCALAPPDATA\nvim" "$env:LOCALAPPDATA\nvim.bak" }
New-Item -ItemType Junction -Path "$env:LOCALAPPDATA\nvim" -Target "$env:USERPROFILE\src\scripts\nvim"
```

5. Open a **new** terminal and run `nvim`. The first launch installs plugins, parsers and Mason tools; let it finish, then check `:checkhealth`.

## 🚀 Usage

Press `Space` and wait: a menu lists every command. The keys used most:

| Keys | What it does |
|---|---|
| `Space Space` / `Space /` | Find file / search text in project |
| `Space e` | File explorer |
| `Shift+h` / `Shift+l`, `Space b d` | Previous / next buffer (tab), close buffer |
| `Ctrl+h/j/k/l`, `Space w d` | Move between windows (panes), close window |
| `Space \|` / `Space -` | Split right / below |
| `gd`, `gr`, `K` | Go to definition, references, hover docs |
| `Space c a`, `Space c r` | Code action, rename |
| `Space c v` | Pick a Python virtualenv (e.g. a uv `.venv`) |
| `Ctrl+/` | Toggle terminal |
| `Space g g` | lazygit |
| `Space l`, `Space c m` | Plugin manager (lazy.nvim), tool manager (Mason) |

New to Vim? Run `nvim --clean +Tutor` (the tutor is disabled in this config).

### Updating

`git pull` this repo, then in Neovim `Space l` → `S` (sync). Commit the updated `lazy-lock.json` so other machines get the same versions.

## 🔍 Troubleshooting

- **`Space` just moves the cursor** - the config isn't loaded. Check `:echo $MYVIMRC` and that `%LOCALAPPDATA%\nvim` points here.
- **Java/Python LSP never starts** - run `python --version` in a new terminal; it must not be the Microsoft Store stub. Then check `:LspInfo` and `:Mason`.
- **`Ctrl+/` opens cmd** - `pwsh` must be on `PATH`.

## 📝 License

The config is based on the [LazyVim starter](https://github.com/LazyVim/starter) (Apache-2.0, see [LICENSE](LICENSE)).

---
*For more utilities, visit the main repository [here](../README.md)*
