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

-- Settings (Ctrl+, / Cmd+, like VS Code)
map(ANY, "<C-,>", function() require("config.shortcuts").settings() end, { desc = "Settings" })

-- Word navigation (Alt / Option + arrows, Alt / Option + Backspace)
map({ "n", "v" }, "<A-Left>", "b", { desc = "Previous word" })
map({ "n", "v" }, "<A-Right>", "w", { desc = "Next word" })
map("i", "<A-Left>", "<C-o>b", { desc = "Previous word" })
map("i", "<A-Right>", "<C-o>w", { desc = "Next word" })
-- noremap: this <C-w> is Vim's built-in "delete word", not the Close tab mapping
map("i", "<A-BS>", "<C-w>", { desc = "Delete previous word" })

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

-- Terminal (Ctrl+` or Ctrl+J like VS Code; Ctrl+Shift+` opens a new one)
map({ "n", "i", "v", "t" }, "<C-`>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
map(ANY, "<C-j>", function() Snacks.terminal() end, { desc = "Toggle terminal" })
-- inside a terminal too, except Claude, which uses Ctrl+J for a new line
map("t", "<C-j>", function()
  if vim.api.nvim_buf_get_name(0):lower():find("claude") then
    return "<C-j>"
  end
  vim.schedule(function() Snacks.terminal() end)
  return ""
end, { expr = true, desc = "Toggle terminal" })
map({ "n", "i", "v", "t" }, "<C-S-`>", function() Snacks.terminal.open() end, { desc = "New terminal" })

-- More VS Code shortcuts (same keys on Windows / Linux with Ctrl, on Mac with Cmd)
map(ANY, "<C-g>", function()
  local win = vim.api.nvim_get_current_win() -- the editor, not the prompt window
  vim.ui.input({ prompt = "Go to line: " }, function(n)
    n = tonumber(n)
    if n and vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { math.max(1, math.min(n, vim.api.nvim_buf_line_count(buf))), 0 })
    end
  end)
end, { desc = "Go to line" })

local function replace(in_file)
  require("lazy").load({ plugins = { "grug-far.nvim" } })
  local file = vim.fn.expand("%")
  require("grug-far").open({
    transient = true,
    prefills = in_file and file ~= "" and { paths = file } or {},
  })
end
map(ANY, "<C-h>", function() replace(true) end, { desc = "Replace in file" })
map(ANY, "<C-S-h>", function() replace(false) end, { desc = "Replace in project" })

map("n", "<C-l>", "V", { desc = "Select line" })
map("i", "<C-l>", "<Esc>V", { desc = "Select line" })
map("v", "<C-l>", "j", { desc = "Extend selection one line" })

map(ANY, "<C-S-l>", function()
  vim.api.nvim_feedkeys(vim.keycode("<Plug>(VM-Select-All)"), "m", false)
end, { desc = "Select all occurrences" })

map("n", "<C-CR>", "o", { desc = "New line below" })
map("n", "<C-S-CR>", "O", { desc = "New line above" })
map("i", "<C-CR>", "<C-o>o", { desc = "New line below" })
map("i", "<C-S-CR>", "<C-o>O", { desc = "New line above" })

map(ANY, "<C-\\>", "<cmd>vsplit<cr>", { desc = "Split editor" })

-- Ctrl+1/2/3 focus editor 1/2/3 (left to right), Ctrl+0 the file explorer
local function editors()
  local wins = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    local side = vim.bo[b].buftype == "terminal" or vim.bo[b].filetype:match("^snacks_") or vim.bo[b].filetype == "vscode_scm"
    if vim.api.nvim_win_get_config(w).relative == "" and (not side or vim.bo[b].filetype == "snacks_dashboard") then
      wins[#wins + 1] = w
    end
  end
  table.sort(wins, function(a, b) return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2] end)
  return wins
end
for i = 1, 3 do
  map({ "n", "i", "v", "t" }, ("<C-%d>"):format(i), function()
    local w = editors()[i]
    if w then
      vim.api.nvim_set_current_win(w)
    end
  end, { desc = ("Focus editor %d"):format(i) })
end
map({ "n", "i", "v", "t" }, "<C-0>", function()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if explorer then
    explorer:focus()
  else
    Snacks.explorer.open()
  end
end, { desc = "Focus explorer" })

-- Markdown: switch between editing and the rendered preview (read-only, like VS Code)
local function markdown_preview()
  if vim.bo.filetype ~= "markdown" then
    -- everywhere else Ctrl+Shift+V keeps pasting, as in the terminal
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
    return
  end
  local on = not vim.b.md_preview
  vim.b.md_preview = on
  require("render-markdown").set_buf(on)
  vim.bo.modifiable = not on
  if on then
    vim.cmd.stopinsert()
  else
    vim.cmd.startinsert()
  end
end
map({ "n", "i", "v", "t" }, "<C-S-v>", markdown_preview, { desc = "Markdown preview / edit" })
map({ "n", "i" }, "<C-k>v", function()
  if vim.bo.filetype == "markdown" then
    markdown_preview()
  end
end, { desc = "Markdown preview / edit" })

map(ANY, "<A-z>", function() vim.wo.wrap = not vim.wo.wrap end, { desc = "Toggle word wrap" })
map({ "n", "i" }, "<F3>", "<cmd>normal! n<cr>", { desc = "Next match" })
map({ "n", "i" }, "<S-F3>", "<cmd>normal! N<cr>", { desc = "Previous match" })
