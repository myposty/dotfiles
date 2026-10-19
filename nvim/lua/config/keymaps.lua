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
-- a diff closes both sides, a side panel closes with its file (lua/config/tabs.lua)
map(ANY, "<C-w>", function() require("config.tabs").close() end, { desc = "Close tab" })
-- from Claude or a terminal too, like VS Code (the tab opens in the code area)
local editor_win -- the code area window (below, with Ctrl+N)
local function cycle(cmd)
  return function()
    if vim.fn.mode() == "t" then
      vim.cmd.stopinsert() -- leave the terminal first, or it takes the typing mode back
    end
    vim.schedule(function()
      local win = editor_win()
      if win then
        vim.api.nvim_set_current_win(win)
      end
      -- in the order of the tab bar, skipping terminals
      vim.cmd(vim.fn.exists(":" .. cmd) == 2 and cmd or (cmd:find("Next") and "bnext" or "bprevious"))
    end)
  end
end
map({ "n", "i", "v", "t" }, "<C-Tab>", cycle("BufferLineCycleNext"), { desc = "Next tab" })
map({ "n", "i", "v", "t" }, "<C-S-Tab>", cycle("BufferLineCyclePrev"), { desc = "Previous tab" })
map(ANY, "<C-PageDown>", "<cmd>bnext<cr>", { desc = "Next tab" })
map(ANY, "<C-PageUp>", "<cmd>bprevious<cr>", { desc = "Previous tab" })

-- Editing
-- Save and keep typing (LazyVim's Ctrl+S drops to Vim's command mode, where letters run commands)
-- A new file has no name yet: Ctrl+S asks for it (like VS Code's Save As), creates its
-- folders and shows it in the explorer
local function save()
  if vim.bo.buftype ~= "" then
    return
  end
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd("silent! write")
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  vim.ui.input({ prompt = "Save as: ", default = vim.fn.getcwd() .. "/", completion = "file" }, function(name)
    if not name or vim.trim(name) == "" or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local path = vim.fs.normalize(vim.fn.fnamemodify(vim.trim(name), ":p"))
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent write " .. vim.fn.fnameescape(path))
    end)
    pcall(function() Snacks.explorer.reveal({ file = path }) end)
  end)
end
map({ "n", "i", "v", "s" }, "<C-s>", save, { desc = "Save" })
-- The change under the cursor: old lines in red, new ones in green, like VS Code's
-- inline diff peek (Esc or moving closes it)
map({ "n", "i" }, "<A-d>", function()
  vim.cmd.stopinsert()
  require("gitsigns").preview_hunk()
end, { desc = "Show what changed here" })
-- New file (Ctrl+N / Cmd+N), ready to type; Ctrl+S then asks for its name.
-- It opens in the code area even from Claude, a terminal or a side panel.
function editor_win()
  local function is_editor(w)
    local b = vim.api.nvim_win_get_buf(w)
    return vim.api.nvim_win_get_config(w).relative == "" and vim.bo[b].buftype == ""
      and not vim.bo[b].filetype:match("^snacks_") and vim.bo[b].filetype ~= "vscode_scm"
  end
  local cur, prev = vim.api.nvim_get_current_win(), vim.fn.win_getid(vim.fn.winnr("#"))
  for _, w in ipairs({ cur, prev }) do
    if w ~= 0 and vim.api.nvim_win_is_valid(w) and is_editor(w) then
      return w
    end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(w) then
      return w
    end
  end
end
local function new_file()
  local win = editor_win()
  if win then
    vim.api.nvim_set_current_win(win)
  elseif vim.bo.buftype == "terminal" or vim.api.nvim_win_get_config(0).relative ~= "" then
    vim.cmd("topleft vnew") -- only panels open: a code area next to them
  end
  vim.cmd("enew")
  vim.cmd.startinsert()
end
map({ "n", "i", "v" }, "<C-n>", new_file, { desc = "New file" })
map("t", "<C-n>", function()
  vim.cmd.stopinsert() -- leave the terminal first, or it takes the typing mode back
  vim.schedule(new_file)
end, { desc = "New file" })
map({ "n", "i" }, "<C-z>", "<cmd>undo<cr>", { desc = "Undo" })
map({ "n", "i" }, "<C-S-z>", "<cmd>redo<cr>", { desc = "Redo" })
-- Ctrl+Y redoes like VS Code on Windows (plain Ctrl key: reaches nvim in every terminal)
map({ "n", "i" }, "<C-y>", "<cmd>redo<cr>", { desc = "Redo" })
-- Select all is Ctrl+A everywhere; Claude has its own universal key (Alt+C)
map({ "n", "i" }, "<C-a>", "<esc>ggVG", { desc = "Select all" })
map("v", "<C-c>", '"+y', { desc = "Copy" })
map("v", "<C-x>", '"+d', { desc = "Cut" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste" })
map({ "n", "i" }, "<C-/>", function() vim.cmd("normal gcc") end, { desc = "Toggle comment" })
map({ "n", "i" }, "<C-_>", function() vim.cmd("normal gcc") end, { desc = "Toggle comment" })
map("v", "<C-/>", "gc", { remap = true, desc = "Toggle comment" })
map("v", "<C-_>", "gc", { remap = true, desc = "Toggle comment" })
map({ "n", "i" }, "<A-Up>", function()
  if vim.fn.line(".") > 1 then -- on the first line ":m .-2" is an invalid range
    vim.cmd("m .-2")
    vim.cmd("normal! ==")
  end
end, { desc = "Move line up" })
map({ "n", "i" }, "<A-Down>", function() vim.cmd("m .+1") vim.cmd("normal! ==") end, { desc = "Move line down" })
map("v", "<A-Up>", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })
map("v", "<A-Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
map({ "n", "i" }, "<S-A-Down>", "<cmd>t.<cr>", { desc = "Duplicate line" })
map("x", "<Tab>", ">gv", { desc = "Indent" })
map("x", "<S-Tab>", "<gv", { desc = "Outdent" })
-- a Shift+arrows selection (Select mode): switch to Visual for the indent and back
map("s", "<Tab>", "<C-g>>gv<C-g>", { desc = "Indent" })
map("s", "<S-Tab>", "<C-g><gv<C-g>", { desc = "Outdent" })
-- Shift+Tab while typing moves the line one level left (Tab already indents)
map("i", "<S-Tab>", "<C-d>", { desc = "Outdent" })

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
local function focus_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if explorer then
    explorer:focus()
  else
    Snacks.explorer.open()
  end
end
map({ "n", "i", "v", "t" }, "<C-0>", focus_explorer, { desc = "Focus explorer" })

-- Markdown: rendered preview / back to editing (see config/markdown.lua)
map({ "n", "i", "v", "t" }, "<C-S-v>", function()
  -- terminals: an image in the clipboard goes to Claude, text is pasted
  if vim.api.nvim_get_mode().mode == "t" then
    require("config.clipboard").paste_in_terminal()
  elseif not require("config.markdown").toggle() then
    -- everywhere else Ctrl+Shift+V keeps pasting, as in the terminal
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end
end, { desc = "Markdown preview / edit" })
-- Ctrl+V in a terminal: macOS Terminal.app, WezTerm and Linux terminals send it as byte 22
map("t", "<C-v>", function() require("config.clipboard").paste_in_terminal() end, { desc = "Paste (image into Claude)" })
-- Ctrl+K V like VS Code, also with Ctrl still held for the V (Ctrl+K Ctrl+V)
map({ "n", "i" }, "<C-k>v", function() require("config.markdown").toggle() end, { desc = "Markdown preview / edit" })
map({ "n", "i" }, "<C-k><C-v>", function() require("config.markdown").toggle() end, { desc = "Markdown preview / edit" })

map(ANY, "<A-z>", function() vim.wo.wrap = not vim.wo.wrap end, { desc = "Toggle word wrap" })
map({ "n", "i" }, "<F3>", "<cmd>normal! n<cr>", { desc = "Next match" })
map({ "n", "i" }, "<S-F3>", "<cmd>normal! N<cr>", { desc = "Previous match" })

-- Universal keys: Alt (Option on a Mac, "Use Option as Meta") reaches nvim in every
-- terminal, unlike Ctrl+Shift / Cmd / Ctrl+digit, which most terminals swallow or
-- send as another key. Same actions as the VS Code keys above.
local ANY_T = { "n", "i", "v", "t" }
map(ANY, "<A-p>", function() Snacks.picker.commands() end, { desc = "Command palette" })
map(ANY, "<A-f>", function() LazyVim.pick("live_grep")() end, { desc = "Search in files" })
map(ANY, "<A-o>", function() Snacks.picker.projects() end, { desc = "Open folder" })
-- replaces LazyVim's Alt+K "move line up" (Alt+Up / Alt+Down still move lines)
map(ANY, "<A-k>", function() require("config.folders").open() end, { desc = "Browse folders" })
map(ANY, "<A-r>", function() Snacks.picker.recent() end, { desc = "Open recent file" })
map(ANY_T, "<A-c>", function()
  require("lazy").load({ plugins = { "claudecode.nvim" } })
  vim.cmd("ClaudeCodeFocus")
end, { desc = "Claude Code" })
map(ANY, "<A-g>", function() Snacks.lazygit() end, { desc = "Git (lazygit)" })
map(ANY_T, "<A-e>", function() Snacks.explorer() end, { desc = "Toggle explorer" })
map(ANY, "<A-m>", function() Snacks.picker.diagnostics() end, { desc = "Problems panel" })
map(ANY, "<A-h>", function() replace(false) end, { desc = "Replace in project" })
map(ANY, "<A-l>", function()
  vim.api.nvim_feedkeys(vim.keycode("<Plug>(VM-Select-All)"), "m", false)
end, { desc = "Select all occurrences" })
-- not in terminal mode: Alt+V is Claude's own image key on Windows
map(ANY, "<A-v>", function() require("config.markdown").toggle() end, { desc = "Markdown preview / edit" })
for i = 1, 3 do
  map(ANY_T, ("<A-%d>"):format(i), function()
    local w = editors()[i]
    if w then
      vim.api.nvim_set_current_win(w)
    end
  end, { desc = ("Focus editor %d"):format(i) })
end
map(ANY_T, "<A-0>", focus_explorer, { desc = "Focus explorer" })
map(ANY, "<A-,>", function() require("config.shortcuts").settings() end, { desc = "Settings" })
map(ANY, "<A-.>", vim.lsp.buf.code_action, { desc = "Quick fix" })
map(ANY_T, "<A-`>", function() Snacks.terminal.open() end, { desc = "New terminal" })
-- Terminal.app keeps Ctrl+Tab, so tabs get Alt keys too
map(ANY, "<A-]>", "<cmd>bnext<cr>", { desc = "Next tab" })
map(ANY, "<A-[>", "<cmd>bprevious<cr>", { desc = "Previous tab" })
