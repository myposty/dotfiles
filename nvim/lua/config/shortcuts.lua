-- VS Code style shortcuts shown in the F1 list and on the start screen.
-- Each entry: keys as you press them, what it does, and the action to run.
local M = {}

M.list = {
  { keys = "Ctrl+Shift+O", desc = "Open folder", run = function() Snacks.picker.projects() end, home = "o" },
  { keys = "Ctrl+Shift+K", desc = "Browse folders", run = function() require("config.folders").open() end, home = "k" },
  { keys = "Ctrl+P", desc = "Find file", run = function() LazyVim.pick("files")() end, home = "f" },
  { keys = "Ctrl+Shift+R", desc = "Recent files", run = function() Snacks.picker.recent() end, home = "r" },
  { keys = "Ctrl+Shift+F", desc = "Search in project", run = function() LazyVim.pick("live_grep")() end, home = "s" },
  { keys = "Ctrl+Shift+P", desc = "Command palette", run = function() Snacks.picker.commands() end, home = "p" },
  { keys = "Ctrl+Shift+A", desc = "Claude Code", run = function() require("lazy").load({ plugins = { "claudecode.nvim" } }) vim.cmd("ClaudeCodeFocus") end, home = "c" },
  { keys = "Ctrl+Shift+G", desc = "Git (commit, push)", run = function() Snacks.lazygit() end, home = "g" },
  { keys = "Ctrl+B", desc = "Git changes panel (opens under the explorer)", run = function() require("config.scm").open() end },
  { keys = "Ctrl+B / Ctrl+Shift+E", desc = "File explorer (show / hide); Ctrl+Shift+E also from Claude", run = function() Snacks.explorer() end, home = "e", home_label = "File explorer", home_keys = "Ctrl+B" },
  { keys = "Space h", desc = "Start screen (logo and shortcuts)", run = function() Snacks.dashboard() end },
  { keys = ":Settings", desc = "Open the nvim configuration files", run = function() require("config.shortcuts").settings() end },
  { keys = ":DotfilesUpdate", desc = "Update the dotfiles from GitHub", run = function() vim.cmd("DotfilesUpdate") end },
  { keys = "Ctrl+`", desc = "Terminal (show / hide)", run = function() Snacks.terminal() end },
  { keys = "Space f T", desc = "New terminal", run = function() Snacks.terminal.open() end },
  { keys = "Ctrl+1 / 2 / 3", desc = "Go to editor 1 / 2 / 3", run = function() vim.cmd("wincmd t") end },
  { keys = "Ctrl+0", desc = "Go to the file explorer", run = function() Snacks.explorer.open() end },
  { keys = "Ctrl+\\", desc = "Split editor", run = function() vim.cmd("vsplit") end },
  { keys = "Ctrl+J", desc = "Terminal (show / hide)", run = function() Snacks.terminal() end },
  { keys = "Ctrl+Shift+`", desc = "New terminal", run = function() Snacks.terminal.open() end },
  { keys = "Ctrl+G", desc = "Go to line", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "m", false) end },
  { keys = "Ctrl+H", desc = "Replace in file", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-h>"), "m", false) end },
  { keys = "Ctrl+Shift+H", desc = "Replace in project", run = function() vim.api.nvim_feedkeys(vim.keycode("<C-S-h>"), "m", false) end },
  { keys = "Ctrl+L", desc = "Select line" },
  { keys = "Ctrl+Shift+L", desc = "Select all occurrences (multi-cursor)" },
  { keys = "Ctrl+Enter / Ctrl+Shift+Enter", desc = "New line below / above" },
  { keys = "Alt+Z", desc = "Toggle word wrap", run = function() vim.wo.wrap = not vim.wo.wrap end },
  { keys = "F3 / Shift+F3", desc = "Next / previous search match" },
  { keys = "Ctrl+,", desc = "Settings", run = function() require("config.shortcuts").settings() end },
  { keys = "Ctrl+Arrows", desc = "Resize panel (or drag the border with the mouse)" },
  { keys = "Space |", desc = "Split right", run = function() vim.cmd("vsplit") end },
  { keys = "Space -", desc = "Split below", run = function() vim.cmd("split") end },
  { keys = "Space w H", desc = "Move panel to the left", run = function() vim.cmd.wincmd("H") end },
  { keys = "Space w L", desc = "Move panel to the right", run = function() vim.cmd.wincmd("L") end },
  { keys = "Space w J", desc = "Move panel to the bottom", run = function() vim.cmd.wincmd("J") end },
  { keys = "Space w K", desc = "Move panel to the top", run = function() vim.cmd.wincmd("K") end },
  { keys = "Space w =", desc = "Make all panels the same size", run = function() vim.cmd.wincmd("=") end },
  { keys = "Space w d", desc = "Close panel", run = function() vim.cmd("close") end },
  { keys = "Ctrl+S", desc = "Save (formats with Prettier), keeps typing", run = function() vim.cmd("write") end },
  { keys = "Esc / i", desc = "Esc: Vim command mode (letters run commands); i: back to typing" },
  { keys = "Ctrl+W / click the X", desc = "Close the file (tab)", run = function() Snacks.bufdelete() end },
  { keys = "Ctrl+Tab", desc = "Next tab", run = function() vim.cmd("bnext") end },
  { keys = "Ctrl+/", desc = "Toggle comment", run = function() vim.cmd("normal gcc") end },
  { keys = "Ctrl+D", desc = "Multi-cursor on next match" },
  { keys = "Alt+Up/Down", desc = "Move line" },
  { keys = "Shift+Alt+Down", desc = "Duplicate line", run = function() vim.cmd("t.") end },
  { keys = "Shift+Alt+F", desc = "Format document", run = function() LazyVim.format({ force = true }) end },
  { keys = "F2", desc = "Rename symbol", run = function() vim.lsp.buf.rename() end },
  { keys = "F12", desc = "Go to definition", run = function() vim.lsp.buf.definition() end },
  { keys = "Shift+F12", desc = "Find references", run = function() Snacks.picker.lsp_references() end },
  { keys = "Ctrl+.", desc = "Quick fix", run = function() vim.lsp.buf.code_action() end },
  { keys = "F8", desc = "Next problem", run = function() vim.diagnostic.jump({ count = 1, float = true }) end },
  { keys = "Ctrl+Shift+M", desc = "Problems panel", run = function() Snacks.picker.diagnostics() end },
  { keys = "Ctrl+Alt+K", desc = "Send file to Claude", run = function() require("lazy").load({ plugins = { "claudecode.nvim" } }) vim.cmd("ClaudeCodeAdd %") end },
  { keys = "Tab", desc = "Accept Copilot suggestion" },
  { keys = "Ctrl+Z / Ctrl+Shift+Z", desc = "Undo / redo" },
  { keys = "Space", desc = "All LazyVim commands (menu)", run = function() require("which-key").show({ global = true }) end },
  { keys = ":Copilot auth", desc = "Sign in to Copilot (once)", run = function() vim.cmd("Copilot auth") end },
  { keys = ":SetName", desc = "Change the name on the start screen", run = function() require("config.logo").ask() end },
  { keys = "F1", desc = "This list" },
}

function M.open()
  local items = {}
  for i, s in ipairs(M.list) do
    items[#items + 1] = { idx = i, text = s.keys .. " " .. s.desc, keys = s.keys, desc = s.desc, run = s.run }
  end
  Snacks.picker({
    title = "Shortcuts",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return {
        { ("%-22s"):format(item.keys), "SnacksPickerSpecial" },
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

-- Start screen entries: the shortcuts flagged with `home`, plus the list itself
function M.dashboard_keys()
  local keys = {}
  -- Nerd Font icons (Font Awesome range) per start screen key
  local icons = {
    o = "\u{f07c}", k = "\u{f114}", f = "\u{f15b}", r = "\u{f1da}", s = "\u{f002}", p = "\u{f120}",
    c = "\u{f086}", g = "\u{f1d3}", e = "\u{f0e8}", ["?"] = "\u{f11c}", [","] = "\u{f013}",
    n = "\u{f007}", l = "\u{f1e6}", q = "\u{f011}",
  }
  local function entry(key, label, keys_text, action)
    return { icon = icons[key] .. " ", key = key, desc = ("%-20s %s"):format(label, keys_text), action = action }
  end
  for _, s in ipairs(M.list) do
    if s.home then
      keys[#keys + 1] = entry(s.home, s.home_label or s.desc, s.home_keys or s.keys, s.run)
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
