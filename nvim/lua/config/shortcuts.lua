-- VS Code style shortcuts shown in the F1 list and on the start screen.
-- Each entry: keys as you press them, what it does, and the action to run.
local M = {}

M.list = {
  { keys = "Ctrl+Shift+O", desc = "Open folder", run = function() Snacks.picker.projects() end, home = "o" },
  { keys = "Ctrl+P", desc = "Find file", run = function() LazyVim.pick("files")() end, home = "f" },
  { keys = "Ctrl+Shift+R", desc = "Recent files", run = function() Snacks.picker.recent() end, home = "r" },
  { keys = "Ctrl+Shift+F", desc = "Search in project", run = function() LazyVim.pick("live_grep")() end, home = "s" },
  { keys = "Ctrl+Shift+P", desc = "Command palette", run = function() Snacks.picker.commands() end, home = "p" },
  { keys = "Ctrl+Shift+A", desc = "Claude Code", run = function() require("lazy").load({ plugins = { "claudecode.nvim" } }) vim.cmd("ClaudeCodeFocus") end, home = "c" },
  { keys = "Ctrl+Shift+G", desc = "Git (commit, push)", run = function() Snacks.lazygit() end, home = "g" },
  { keys = "Ctrl+B", desc = "File explorer", run = function() Snacks.explorer() end },
  { keys = "Ctrl+`", desc = "Terminal", run = function() Snacks.terminal() end },
  { keys = "Ctrl+S", desc = "Save", run = function() vim.cmd("write") end },
  { keys = "Ctrl+W", desc = "Close tab", run = function() Snacks.bufdelete() end },
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
  for _, s in ipairs(M.list) do
    if s.home then
      keys[#keys + 1] = { key = s.home, desc = ("%-20s %s"):format(s.desc, s.keys), action = s.run }
    end
  end
  keys[#keys + 1] = { key = "?", desc = ("%-20s %s"):format("All shortcuts", "F1"), action = M.open }
  keys[#keys + 1] = { key = "l", desc = ("%-20s %s"):format("Plugins", ":Lazy"), action = ":Lazy" }
  keys[#keys + 1] = { key = "q", desc = ("%-20s %s"):format("Quit", ":qa"), action = ":qa" }
  return keys
end

return M
