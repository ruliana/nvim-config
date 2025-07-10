-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim\n", "ErrorMsg" },
      { out, "WarningMsg" }
    }, true, {})
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Set leader keys before lazy setup
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Enable line numbers
vim.opt.number = true

-- Always show sign column for LSP messages
vim.opt.signcolumn = "yes"

-- Enable smart case search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Use very magic regular expressions by default
vim.opt.magic = true

-- Clear search highlighting with Escape
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true })

-- Initialize lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = true },
})

-- Load configurations
require("config.keybindings")
require("config.markdown")
require("config.python")
