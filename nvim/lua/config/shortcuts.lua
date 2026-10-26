-- VS Code style shortcuts shown in the F1 list and on the start screen.
-- Each entry: keys as you press them (the VS Code key), `alt` = the universal key that
-- reaches nvim in every terminal (when the VS Code key needs Ctrl+Shift / Cmd), what it
-- does, and the action to run.
local M = {}

M.list = {
  { keys = "Ctrl+Shift+O", alt = "Alt+O", desc = "Open folder", run = function() Snacks.picker.projects() end, home = "o" },
  { keys = "Ctrl+Shift+K", alt = "Alt+K", desc = "Browse folders", run = function() require("config.folders").open() end, home = "k" },
  { keys = "Ctrl+P", desc = "Find file", run = function() LazyVim.pick("files")() end, home = "f" },
  { keys = "Ctrl+Shift+R", alt = "Alt+R", desc = "Recent files", run = function() Snacks.picker.recent() end, home = "r" },
  { keys = "Ctrl+Shift+F", alt = "Alt+F", desc = "Search in project", run = function() LazyVim.pick("live_grep")() end, home = "s" },
  { keys = "Ctrl+Shift+P", alt = "Alt+P", desc = "Command palette", run = function() Snacks.picker.commands() end, home = "p" },
  { keys = "Ctrl+Shift+A", alt = "Alt+C", desc = "Claude Code", run = function() require("lazy").load({ plugins = { "claudecode.nvim" } }) vim.cmd("ClaudeCodeFocus") end, home = "c" },
  { keys = "Ctrl+Shift+G", alt = "Alt+G", desc = "Git (commit, push)", run = function() Snacks.lazygit() end, home = "g" },
  { keys = "Ctrl+B", desc = "Git changes panel (opens under the explorer)", run = function() require("config.scm").open() end },
  { keys = "Ctrl+B / Ctrl+Shift+E", alt = "Ctrl+B / Alt+E", desc = "File explorer (show / hide); Ctrl+Shift+E / Alt+E also from Claude", run = function() Snacks.explorer() end, home = "e", home_label = "File explorer", home_keys = "Ctrl+B" },
  { keys = "Space h", desc = "Start screen (logo and shortcuts)", run = function() Snacks.dashboard() end },
  { keys = "1 … 5 on the start screen / :Sessions", desc = "Reopen a recent session (folder, files, splits)", run = function() vim.cmd("Sessions") end },
  { keys = ":Settings", desc = "Open the nvim configuration files", run = function() require("config.shortcuts").settings() end },
  { keys = ":DotfilesUpdate", desc = "Update the dotfiles from GitHub", run = function() vim.cmd("DotfilesUpdate") end },
  { keys = "Ctrl+`", desc = "Terminal (show / hide)", run = function() require("config.tabs").toggle_terminal() end },
  { keys = "Space f T", desc = "New terminal", run = function() Snacks.terminal.open() end },
  { keys = "Ctrl+1 / 2 / 3", alt = "Alt+1 / 2 / 3", desc = "Go to editor 1 / 2 / 3", run = function() vim.cmd("wincmd t") end },
  { keys = "Ctrl+0", alt = "Alt+0", desc = "Go to the file explorer", run = function() Snacks.explorer.open() end },
  { keys = "Ctrl+\\", desc = "Split editor", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-\\>"), "m", false) end },
  { keys = "Ctrl+J", desc = "Terminal (show / hide)", run = function() require("config.tabs").toggle_terminal() end },
  { keys = "Ctrl+Shift+`", alt = "Alt+`", desc = "New terminal", run = function() Snacks.terminal.open() end },
  { keys = "Ctrl+G", desc = "Go to line", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "m", false) end },
  { keys = "Ctrl+H", desc = "Replace in file", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-h>"), "m", false) end },
  { keys = "Ctrl+Shift+H", alt = "Alt+H", desc = "Replace in project", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-S-h>"), "m", false) end },
  { keys = "Ctrl+L", desc = "Select line" },
  { keys = "Ctrl+Shift+L", alt = "Alt+L", desc = "Select all occurrences (multi-cursor)" },
  { keys = "Ctrl+Enter / Ctrl+Shift+Enter", desc = "New line below / above" },
  { keys = "Ctrl+Shift+V / Ctrl+K V", alt = "Alt+V / Ctrl+K V", desc = "Markdown: preview / edit (or click Preview at the top right)", run = function() vim.cmd("MarkdownPreview") end },
  { keys = "Ctrl+V / Ctrl+Shift+V in Claude", desc = "Paste the copied image (or text) into Claude" },
  { keys = "Open an image file", desc = "Preview it (WezTerm, kitty, ghostty) or open it in the system viewer" },
  { keys = "Click a file path in Claude", desc = "Open it in the editor (diff lines open at that line)" },
  { keys = "Alt+Z", desc = "Toggle word wrap", run = function() vim.wo.wrap = not vim.wo.wrap end },
  { keys = "F3 / Shift+F3", desc = "Next / previous search match" },
  { keys = "Ctrl+,", alt = "Alt+,", desc = "Settings", run = function() require("config.shortcuts").settings() end },
  { keys = "Ctrl+Arrows", desc = "Resize panel (or drag the border with the mouse)" },
  { keys = "Space |", desc = "Split right", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-\\>"), "m", false) end },
  { keys = "Space -", desc = "Split below", run = function() vim.api.nvim_feedkeys(vim.keycode("<Esc><Space>-"), "m", false) end },
  { keys = "Space w H", desc = "Move panel to the left", run = function() vim.cmd.wincmd("H") end },
  { keys = "Space w L", desc = "Move panel to the right", run = function() vim.cmd.wincmd("L") end },
  { keys = "Space w J", desc = "Move panel to the bottom", run = function() vim.cmd.wincmd("J") end },
  { keys = "Space w K", desc = "Move panel to the top", run = function() vim.cmd.wincmd("K") end },
  { keys = "Space w =", desc = "Make all panels the same size", run = function() vim.cmd.wincmd("=") end },
  { keys = "Space w d", desc = "Close panel", run = function() vim.cmd("close") end },
  { keys = "Ctrl+S", desc = "Save (formats with Prettier); a new file asks for its name", run = function() vim.cmd("write") end },
  { keys = "Ctrl+N", desc = "New file, from anywhere (Ctrl+S then asks for its name)", run = function() vim.cmd("enew") end },
  { keys = "a / A in the explorer", desc = "New file / new folder inside the selected folder (Ctrl+N: new file too; or the buttons on top of the explorer)" },
  { keys = "Shift+Arrows, then Tab / Shift+Tab", desc = "Select lines, then indent / outdent them" },
  { keys = ":SecretsToggle", desc = "Show / hide .env values (hidden as ****** by default)", run = function() require("config.secrets").toggle() end },
  { keys = "Click the branch (status bar or Git panel)", desc = "Switch branch (Ctrl+A in the list: new branch)", run = function() Snacks.picker.git_branches() end },
  { keys = "Double-click a file in the Git panel", desc = "Open it with its changes: new lines green, removed ones red above (one click only selects; x discard, s stage, ? all keys)" },
  { keys = "Right click in the explorer / Git panel", desc = "Menu: new file / folder, rename, delete, cut / copy / paste, copy path, stage, discard..." },
  { keys = "r / d / c / m in the explorer", desc = "Rename / delete / copy / move" },
  { keys = "Alt+D", desc = "What changed here: old lines in red, new in green (changed lines are highlighted)", run = function() require("gitsigns").preview_hunk() end },
  { keys = "Esc / i", desc = "Esc: Vim command mode (letters run commands); i: back to typing" },
  { keys = "Ctrl+W / click the X / middle click", desc = "Close the file (tab); a diff closes both sides, a side panel closes with it", run = function() require("config.tabs").close() end },
  { keys = "Right click a tab", desc = "Close, Close Others, Close to the Right, Close All, Copy Path, Reveal" },
  { keys = "Ctrl+Tab / Ctrl+Shift+Tab", alt = "Alt+] / Alt+[", desc = "Next / previous tab", run = function() vim.cmd("bnext") end },
  { keys = "Ctrl+/", desc = "Toggle comment", run = function() vim.cmd("normal gcc") end },
  { keys = "Ctrl+D", desc = "Multi-cursor on next match" },
  { keys = "Alt+Up/Down", desc = "Move line" },
  { keys = "Shift+Alt+Down", desc = "Duplicate line", run = function() vim.cmd("t.") end },
  { keys = "Shift+Alt+F", desc = "Format document", run = function() LazyVim.format({ force = true }) end },
  { keys = "F2", desc = "Rename symbol", run = function() vim.lsp.buf.rename() end },
  { keys = "F12", desc = "Go to definition", run = function() vim.lsp.buf.definition() end },
  { keys = "Shift+F12", desc = "Find references", run = function() Snacks.picker.lsp_references() end },
  { keys = "Ctrl+.", alt = "Alt+.", desc = "Quick fix", run = function() vim.lsp.buf.code_action() end },
  { keys = "F8", desc = "Next problem", run = function() vim.diagnostic.jump({ count = 1, float = true }) end },
  { keys = "Ctrl+Shift+M", alt = "Alt+M", desc = "Problems panel", run = function() Snacks.picker.diagnostics() end },
  { keys = "Ctrl+Alt+K", desc = "Send file to Claude", run = function() require("lazy").load({ plugins = { "claudecode.nvim" } }) vim.cmd("ClaudeCodeAdd %") end },
  { keys = "Tab", desc = "Indent (or accept the Copilot suggestion when one shows)" },
  { keys = "Ctrl+Z / Ctrl+Shift+Z", alt = "Ctrl+Z / Ctrl+Y", desc = "Undo / redo (Ctrl+Y also redoes)" },
  { keys = "Space", desc = "All LazyVim commands (menu)", run = function() require("which-key").show({ global = true }) end },
  { keys = ":Copilot auth", desc = "Sign in to Copilot (once)", run = function() vim.cmd("Copilot auth") end },
  { keys = ":SetName", desc = "Change the name on the start screen", run = function() require("config.logo").ask() end },
  { keys = "F1", desc = "This list" },
}

-- On a Mac the shortcuts use Cmd instead of Ctrl, like VS Code for Mac (WezTerm,
-- which install.sh sets up, forwards Cmd to nvim; see wezterm.lua).
-- NVIM_FORCE_MAC=1 shows the Mac labels on another OS (to check them).
local function cmd_keys()
  return vim.uv.os_uname().sysname == "Darwin" or vim.env.NVIM_FORCE_MAC == "1"
end
-- VS Code for Mac uses other keys for these
local MAC_KEYS = {
  ["Ctrl+H"] = "Cmd+Option+F",
  ["Ctrl+Tab / Ctrl+Shift+Tab"] = "Cmd+Shift+] / Cmd+Shift+[",
  ["Ctrl+`"] = "Ctrl+`",
  -- Ctrl+Up/Down is Mission Control on a Mac: no key for it there
  ["Ctrl+Arrows"] = "Drag the border",
  -- Terminal.app keeps Cmd+Shift+V (paste); Ctrl+K V reaches nvim in every terminal
  ["Ctrl+Shift+V / Ctrl+K V"] = "Cmd+Shift+V / Ctrl+K V",
}

-- The keys of a shortcut as they are pressed on this machine
function M.label(keys)
  if not cmd_keys() then
    return keys
  end
  return MAC_KEYS[keys] or (keys:gsub("Ctrl%+", "Cmd+"):gsub("Alt%+", "Option+"))
end

-- The universal keys: Ctrl stays Ctrl (plain Ctrl+letter reaches nvim everywhere,
-- Cmd does not), Alt is called Option on a Mac
local function alt_label(keys)
  if not cmd_keys() then
    return keys
  end
  return (keys:gsub("Alt%+", "Option+"))
end

-- True when the terminal delivers the VS Code keys (Ctrl+Shift, Cmd) to nvim:
-- WezTerm and Windows Terminal, which this repo configures to forward them
function M.forwards()
  return vim.env.TERM_PROGRAM == "WezTerm" or vim.env.WEZTERM_PANE ~= nil or vim.env.WT_SESSION ~= nil
end

-- The key of an entry that works in the terminal in use
function M.entry_label(entry)
  if M.forwards() then
    return M.label(entry.keys)
  end
  -- elsewhere Cmd never arrives: the universal key, or the plain Ctrl one
  if cmd_keys() and entry.keys == "Ctrl+Arrows" then
    return MAC_KEYS[entry.keys]
  end
  return alt_label(entry.alt or entry.keys)
end

-- False only when the terminal font is known to lack Nerd Font glyphs (they would
-- show as "?" boxes). Only Terminal.app can be checked: its font is in its preferences.
-- NVIM_NERD_FONT=0/1 forces the answer (to test).
local nerd
local function hex(s)
  return (s:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
function M.nerd_font()
  if nerd ~= nil then
    return nerd
  end
  local force = vim.env.NVIM_NERD_FONT
  if force == "0" or force == "1" then
    nerd = force == "1"
  elseif vim.uv.os_uname().sysname == "Darwin" and vim.env.TERM_PROGRAM == "Apple_Terminal" then
    -- the dump keeps font names as plain text or as hex bytes: look for both
    local out = vim.fn.system({ "defaults", "read", "com.apple.Terminal" })
    local plain = out:lower()
    local bytes = plain:gsub("%s", "")
    nerd = vim.v.shell_error ~= 0 or out == "" -- cannot tell: assume it has them
    for _, mark in ipairs({ "Nerd", "NF-", "NFM-" }) do
      mark = mark:lower()
      if plain:find(mark, 1, true) or bytes:find(hex(mark), 1, true) then
        nerd = true
      end
    end
  else
    nerd = true
  end
  return nerd
end

function M.open()
  local items = {}
  for i, s in ipairs(M.list) do
    local keys = M.entry_label(s)
    if s.alt and M.forwards() then
      -- the terminal delivers both: show the VS Code key and the universal one
      keys = M.label(s.keys) .. "  ·  " .. alt_label(s.alt)
    end
    items[#items + 1] = { idx = i, text = keys .. " " .. s.desc, keys = keys, desc = s.desc, run = s.run }
  end
  -- the keys column fits its longest entry (both keys can be shown), within reason;
  -- a longer one still keeps two spaces before its description
  local column = 0
  for _, item in ipairs(items) do
    column = math.max(column, vim.fn.strdisplaywidth(item.keys))
  end
  column = math.min(column, 32) + 2
  Snacks.picker({
    title = "Shortcuts",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      local pad = math.max(column - vim.fn.strdisplaywidth(item.keys), 2)
      return {
        { item.keys .. (" "):rep(pad), "SnacksPickerSpecial" },
        { item.desc, item.run and "SnacksPickerLabel" or "SnacksPickerComment" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if item and item.run then
        vim.schedule(item.run)
      end
    end,
  })
end

-- A start screen row: "Name ······ Keys ······" with faint dot leaders, so the eye
-- follows each name to its keys and to the letter at the end of the row
local NAME_COL, ROW_WIDTH = 21, 44
-- the comment color, without its italics (slanted dots look broken)
local function leader_hl()
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  vim.api.nvim_set_hl(0, "DashboardLeader", { fg = comment.fg, ctermfg = comment.ctermfg })
end
leader_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = leader_hl })
function M.row(label, keys)
  local w = vim.fn.strdisplaywidth
  label = vim.fn.strcharpart(label, 0, NAME_COL - 2)
  local lead1 = (" " .. ("·"):rep(math.max(1, NAME_COL - w(label) - 2)) .. " ")
  local used = w(label) + w(lead1) + w(keys)
  local lead2 = (" " .. ("·"):rep(math.max(1, ROW_WIDTH - used - 2)) .. " ")
  return {
    { label, hl = "desc" },
    { lead1, hl = "DashboardLeader" },
    { keys, hl = "desc" },
    { lead2, hl = "DashboardLeader" },
  }
end

-- Start screen entries: the shortcuts flagged with `home`, plus the list itself
function M.dashboard_keys()
  local keys = {}
  -- Nerd Font icons (Font Awesome range) per start screen key; plain Unicode symbols
  -- (any system font has them) when the terminal font has no Nerd glyphs
  local icons = {
    o = "\u{f07c}", k = "\u{f114}", f = "\u{f15b}", r = "\u{f1da}", s = "\u{f002}", p = "\u{f120}",
    c = "\u{f086}", g = "\u{f1d3}", e = "\u{f0e8}", ["?"] = "\u{f11c}", [","] = "\u{f013}",
    n = "\u{f040}", l = "\u{f12e}", q = "\u{f08b}",
  }
  if not M.nerd_font() then
    icons = {
      o = "▸", k = "⌕", f = "≡", r = "↺", s = "⊙", p = "❯",
      c = "✦", g = "⎇", e = "☰", ["?"] = "?", [","] = "⚙",
      n = "✎", l = "⧉", q = "⏻",
    }
  end
  -- keys_text is already the label to show
  local function entry(key, label, keys_text, action)
    return { icon = icons[key] .. " ", key = key, desc = M.row(label, keys_text), action = action }
  end
  for _, s in ipairs(M.list) do
    if s.home then
      -- home_keys (Ctrl+B) is a plain Ctrl key: it works in every terminal
      local text = s.home_keys and M.entry_label({ keys = s.home_keys }) or M.entry_label(s)
      keys[#keys + 1] = entry(s.home, s.home_label or s.desc, text, s.run)
    end
  end
  keys[#keys + 1] = entry("?", "All shortcuts", "F1", M.open)
  keys[#keys + 1] = entry(",", "Settings", ":Settings", function() M.settings() end)
  keys[#keys + 1] = entry("n", "Change name", ":SetName", function() require("config.logo").ask() end)
  keys[#keys + 1] = entry("l", "Plugins", ":Lazy", ":Lazy")
  keys[#keys + 1] = entry("q", "Quit", ":qa", ":qa")
  return keys
end

-- Settings: pick any file of this nvim configuration
function M.settings()
  Snacks.picker.files({ cwd = vim.fn.stdpath("config"), title = "Settings" })
end
vim.api.nvim_create_user_command("Settings", M.settings, { desc = "Open the nvim configuration files" })

return M
