-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- VS Code style shortcuts layered on top of LazyVim defaults.
-- Files open ready to type (see autocmds.lua), so the shortcuts work while typing too.

local map = vim.keymap.set
local ANY = { "n", "i", "v" } -- normal, typing and selection

vim.keymap.set('n', '<leader>c', '<cmd>bd<CR>', { desc = 'Cerrar buffer actual' })

-- Shortcut list (F1 or :Shortcuts)
map(ANY, "<F1>", function() require("config.shortcuts").open() end, { desc = "All shortcuts" })
vim.api.nvim_create_user_command("Shortcuts", function() require("config.shortcuts").open() end, {})

-- Start screen (logo + shortcuts)
map("n", "<leader>h", function() Snacks.dashboard() end, { desc = "Start screen" })
vim.api.nvim_create_user_command("Home", function() Snacks.dashboard() end, {})

-- Files and search
map(ANY, "<C-p>", function() LazyVim.pick("files")() end, { desc = "Find files (Ctrl+P)" })
map(ANY, "<C-S-p>", function() Snacks.picker.commands() end, { desc = "Command palette" })
map(ANY, "<C-S-f>", function() LazyVim.pick("live_grep")() end, { desc = "Search in files" })
map({ "n", "i" }, "<C-f>", function() vim.cmd.stopinsert() vim.api.nvim_feedkeys("/", "n", false) end, { desc = "Find in file" })
map(ANY, "<C-b>", function() Snacks.explorer() end, { desc = "Toggle explorer" })
-- Works inside Claude and terminals too, where Ctrl+B belongs to the app
map({ "n", "i", "v", "t" }, "<C-S-e>", function() Snacks.explorer() end, { desc = "Toggle explorer" })
map(ANY, "<C-S-g>", function() Snacks.lazygit() end, { desc = "Git (lazygit)" })
map("n", "<C-k><C-o>", function() Snacks.picker.projects() end, { desc = "Open folder" })
map(ANY, "<C-S-o>", function() Snacks.picker.projects() end, { desc = "Open folder" })
map(ANY, "<C-S-k>", function() require("config.folders").open() end, { desc = "Browse folders" })
map(ANY, "<C-S-r>", function() Snacks.picker.recent() end, { desc = "Open recent file" })

-- Buffers (tabs)
map(ANY, "<C-w>", function() Snacks.bufdelete() end, { desc = "Close tab" })
map(ANY, "<C-Tab>", "<cmd>bnext<cr>", { desc = "Next tab" })
map(ANY, "<C-S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous tab" })
map(ANY, "<C-PageDown>", "<cmd>bnext<cr>", { desc = "Next tab" })
map(ANY, "<C-PageUp>", "<cmd>bprevious<cr>", { desc = "Previous tab" })

-- Editing
-- Save and keep typing (LazyVim's Ctrl+S drops to Vim's command mode, where letters run commands)
map({ "n", "i", "v", "s" }, "<C-s>", "<cmd>w<cr>", { desc = "Save" })
map({ "n", "i" }, "<C-z>", "<cmd>undo<cr>", { desc = "Undo" })
map({ "n", "i" }, "<C-S-z>", "<cmd>redo<cr>", { desc = "Redo" })
map({ "n", "i" }, "<C-a>", "<esc>ggVG", { desc = "Select all" })
map("v", "<C-c>", '"+y', { desc = "Copy" })
map("v", "<C-x>", '"+d', { desc = "Cut" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste" })
map({ "n", "i" }, "<C-/>", function() vim.cmd("normal gcc") end, { desc = "Toggle comment" })
map({ "n", "i" }, "<C-_>", function() vim.cmd("normal gcc") end, { desc = "Toggle comment" })
map("v", "<C-/>", "gc", { remap = true, desc = "Toggle comment" })
map("v", "<C-_>", "gc", { remap = true, desc = "Toggle comment" })
map({ "n", "i" }, "<A-Up>", function() vim.cmd("m .-2") vim.cmd("normal! ==") end, { desc = "Move line up" })
map({ "n", "i" }, "<A-Down>", function() vim.cmd("m .+1") vim.cmd("normal! ==") end, { desc = "Move line down" })
map("v", "<A-Up>", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })
map("v", "<A-Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
map({ "n", "i" }, "<S-A-Down>", "<cmd>t.<cr>", { desc = "Duplicate line" })
map("v", "<Tab>", ">gv", { desc = "Indent" })
map("v", "<S-Tab>", "<gv", { desc = "Outdent" })

-- Code (LSP)
map(ANY, "<S-A-f>", function() LazyVim.format({ force = true }) end, { desc = "Format document" })
map(ANY, "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map(ANY, "<F12>", vim.lsp.buf.definition, { desc = "Go to definition" })
map(ANY, "<S-F12>", function() Snacks.picker.lsp_references() end, { desc = "Find references" })
map(ANY, "<C-.>", vim.lsp.buf.code_action, { desc = "Quick fix" })
map(ANY, "<F8>", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next problem" })
map(ANY, "<C-S-m>", function() Snacks.picker.diagnostics() end, { desc = "Problems panel" })

-- Terminal (Ctrl+`)
map({ "n", "i", "v", "t" }, "<C-`>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
map({ "n", "i" }, "<C-\\>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
