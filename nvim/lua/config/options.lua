-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

opt.relativenumber = false -- absolute line numbers, like VS Code
opt.mouse = "a"
opt.clipboard = "unnamedplus"
-- Long lines continue below instead of being cut, and follow the panel width
opt.wrap = true
opt.linebreak = true
opt.breakindent = true
-- No auto-scroll near the edges: a click or mouse selection stays where you put it, like VS Code
opt.scrolloff = 0
-- No swap files: no "ATTENTION, swap file found" prompt after a crash or when the same
-- file is open twice (like VS Code). Undo history is still kept in undofile.
opt.swapfile = false
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true

-- PHP: intelephense (Node based) works without a local PHP install, same as VS Code
vim.g.lazyvim_php_lsp = "intelephense"

-- Show AI suggestions as inline grey text (Tab to accept), like Copilot in VS Code
vim.g.ai_cmp = false
