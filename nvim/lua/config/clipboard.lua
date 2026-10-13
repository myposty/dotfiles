-- Paste an image from the system clipboard into Claude Code.
-- Claude reads the clipboard itself when it gets its image key (Alt+V on Windows,
-- Ctrl+V elsewhere); inside nvim's terminal we only have to send that key.
local M = {}

local TIMEOUT = 2000

local function run(cmd)
  local ok, res = pcall(function() return vim.system(cmd, { text = true }):wait(TIMEOUT) end)
  if not ok or not res or res.code ~= 0 then
    return nil
  end
  return res.stdout or ""
end

function M.has_image()
  if vim.fn.has("win32") == 1 then
    local out = run({ "powershell", "-NoProfile", "-NonInteractive", "-Command",
      "Add-Type -AssemblyName System.Windows.Forms; [Windows.Forms.Clipboard]::ContainsImage()" })
    return out ~= nil and out:find("True") ~= nil
  elseif vim.fn.has("mac") == 1 then
    local out = run({ "osascript", "-e", "clipboard info" })
    return out ~= nil and (out:find("PNGf") or out:find("TIFF") or out:find("JPEG")) ~= nil
  end
  local out
  if vim.fn.executable("wl-paste") == 1 then
    out = run({ "wl-paste", "--list-types" })
  elseif vim.fn.executable("xclip") == 1 then
    out = run({ "xclip", "-selection", "clipboard", "-t", "TARGETS", "-o" })
  end
  for line in (out or ""):gmatch("[^\r\n]+") do
    if line:find("^image/") then
      return true
    end
  end
  return false
end

function M.paste_in_terminal()
  local claude = vim.api.nvim_buf_get_name(0):lower():find("claude", 1, true)
  if claude and M.has_image() then
    local key = vim.fn.has("win32") == 1 and "\27v" or "\22"
    vim.api.nvim_chan_send(vim.b.terminal_job_id, key)
  else
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end
end

return M
