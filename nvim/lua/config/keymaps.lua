-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- VS Code style shortcuts layered on top of LazyVim defaults.

local map = vim.keymap.set

vim.keymap.set('n', '<leader>c', '<cmd>bd<CR>', { desc = 'Cerrar buffer actual' })

-- Files and search
map("n", "<C-p>", function() LazyVim.pick("files")() end, { desc = "Find files (Ctrl+P)" })
map({ "n", "i", "v" }, "<C-S-p>", function() Snacks.picker.commands() end, { desc = "Command palette" })
map("n", "<C-S-f>", function() LazyVim.pick("live_grep")() end, { desc = "Search in files" })
map("n", "<C-f>", "/", { desc = "Find in file" })
map("n", "<C-b>", function() Snacks.explorer() end, { desc = "Toggle explorer" })
map("n", "<C-S-e>", function() Snacks.explorer() end, { desc = "Toggle explorer" })
map("n", "<C-S-g>", function() Snacks.lazygit() end, { desc = "Git (lazygit)" })
map("n", "<C-k><C-o>", function() Snacks.picker.projects() end, { desc = "Open folder" })
map("n", "<C-S-o>", function() Snacks.picker.projects() end, { desc = "Open folder" })
map("n", "<C-S-r>", function() Snacks.picker.recent() end, { desc = "Open recent file" })

-- Buffers (tabs)
map("n", "<C-w>", function() Snacks.bufdelete() end, { desc = "Close tab" })
map("n", "<C-Tab>", "<cmd>bnext<cr>", { desc = "Next tab" })
map("n", "<C-S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous tab" })
map("n", "<C-PageDown>", "<cmd>bnext<cr>", { desc = "Next tab" })
map("n", "<C-PageUp>", "<cmd>bprevious<cr>", { desc = "Previous tab" })

-- Editing
map({ "n", "i" }, "<C-z>", "<cmd>undo<cr>", { desc = "Undo" })
map({ "n", "i" }, "<C-S-z>", "<cmd>redo<cr>", { desc = "Redo" })
map("n", "<C-a>", "ggVG", { desc = "Select all" })
map("v", "<C-c>", '"+y', { desc = "Copy" })
map("v", "<C-x>", '"+d', { desc = "Cut" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste" })
map({ "n", "v" }, "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
map({ "n", "v" }, "<C-_>", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<C-/>", "gc", { remap = true, desc = "Toggle comment" })
map("v", "<C-_>", "gc", { remap = true, desc = "Toggle comment" })
map("n", "<A-Up>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("n", "<A-Down>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("v", "<A-Up>", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })
map("v", "<A-Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
map("n", "<S-A-Down>", "<cmd>t.<cr>", { desc = "Duplicate line" })
map("v", "<Tab>", ">gv", { desc = "Indent" })
map("v", "<S-Tab>", "<gv", { desc = "Outdent" })

-- Code (LSP)
map({ "n", "v" }, "<S-A-f>", function() LazyVim.format({ force = true }) end, { desc = "Format document" })
map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<F12>", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "<S-F12>", function() Snacks.picker.lsp_references() end, { desc = "Find references" })
map({ "n", "v" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Quick fix" })
map("n", "<F8>", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next problem" })
map("n", "<C-S-m>", function() Snacks.picker.diagnostics() end, { desc = "Problems panel" })

-- Terminal (Ctrl+`)
map({ "n", "t" }, "<C-`>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
map({ "n", "t" }, "<C-\\>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
