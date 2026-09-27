-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Close the lazy.nvim window with <Esc> (https://github.com/folke/lazy.nvim/discussions/1196)
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_lazy_esc", { clear = true }),
  pattern = "lazy",
  desc = "Quit lazy with <esc>",
  callback = function()
    vim.keymap.set("n", "<esc>", function()
      vim.api.nvim_win_close(0, false)
    end, { buffer = true, nowait = true })
  end,
})
