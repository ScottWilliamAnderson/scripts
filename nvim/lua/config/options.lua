-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use PowerShell 7 for the terminal (<C-/>) and :! commands instead of cmd.exe
LazyVim.terminal.setup("pwsh")

-- Python LSP for the lang.python extra: ty instead of pyright
vim.g.lazyvim_python_lsp = "ty"
