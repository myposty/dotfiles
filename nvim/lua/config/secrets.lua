-- Secrets show as ******** instead of their value, like VS Code's Cloak extension:
-- * .env files (.env, .env.local, prod.env, .envrc, .dev.vars): every value
-- * any other file: only keys that look secret (PASSWORD, TOKEN, API_KEY, ...)
-- A line you type on shows its real value until the cursor leaves it.
-- :SecretsToggle (or the command palette) shows or hides them everywhere.
local M = {}

local ns = vim.api.nvim_create_namespace("vscode_secrets")
M.enabled = true

local SECRET_KEY = { "pass", "pwd", "secret", "token", "api_?key", "apikey", "private", "access_?key", "credential",
  "auth", "client_?id", "database_?url", "db_?url", "dsn", "connection", "webhook", "salt", "signing" }

local function is_env_file(name)
  local base = vim.fs.basename(name):lower()
  return base:match("^%.env") ~= nil or base:match("%.env$") ~= nil or base == ".dev.vars"
end
M.is_env_file = is_env_file

local function secret_key(key)
  key = key:lower()
  for _, pat in ipairs(SECRET_KEY) do
    if key:find(pat) then
      return true
    end
  end
  return false
end

-- The value part of a `KEY=value` / `KEY: value` / `"key": "value"` line, as 0-based
-- start and end columns, or nil. `all` masks any key (env files).
function M.value_range(line, all)
  if line:match("^%s*[#;/]") then
    return nil
  end
  local key, s, value = line:match("^%s*export%s+([%w_%.%-]+)%s*=%s*()(.-)%s*$")
  if not key then
    key, s, value = line:match("^%s*[\"']?([%w_%.%-]+)[\"']?%s*[=:]%s*()(.-)%s*,?%s*$")
  end
  if not key or value == "" or not (all or secret_key(key)) then
    return nil
  end
  -- keep the quotes around a quoted value visible
  local q = value:sub(1, 1)
  if (q == '"' or q == "'") and #value > 1 and value:sub(-1) == q then
    s, value = s + 1, value:sub(2, -2)
  end
  if value == "" or (not all and (value == "true" or value == "false" or value:match("^[{%[]"))) then
    return nil
  end
  return s - 1, s - 1 + #value
end

-- `name`: the file shown, for a preview buffer that has no name of its own
local function mask(buf, name)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not M.enabled or (vim.bo[buf].buftype ~= "" and not name) then
    return
  end
  local all = is_env_file(name or vim.api.nvim_buf_get_name(buf))
  if not all and vim.api.nvim_buf_line_count(buf) > 5000 then
    return
  end
  -- the line being typed on shows its real value until the cursor leaves it
  local open = vim.b[buf].secrets_edit_row or -1
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local s, e = M.value_range(line, all)
    if s and i - 1 ~= open then
      -- one star over each character: a long value that wraps stays covered
      for _, pos in ipairs(vim.str_utf_pos(line:sub(s + 1, e))) do
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s + pos - 1, {
          virt_text = { { "*", "Comment" } },
          virt_text_pos = "overlay",
          priority = 200,
        })
      end
    end
  end
end
M.mask = mask

local group = vim.api.nvim_create_augroup("vscode_secrets", { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI", "BufLeave", "InsertLeave" }, {
  group = group,
  callback = function(ev)
    local b = vim.b[ev.buf]
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    if ev.event == "TextChanged" or ev.event == "TextChangedI" then
      -- typed by you (a reload from disk is not an edit)
      b.secrets_edit_row = vim.api.nvim_get_current_buf() == ev.buf and vim.bo[ev.buf].modified and row or nil
    elseif ev.event == "CursorMoved" or ev.event == "CursorMovedI" then
      if b.secrets_edit_row == nil or b.secrets_edit_row == row then
        return -- nothing open, or still on the open line
      end
      b.secrets_edit_row = nil
    elseif ev.event == "BufLeave" or ev.event == "InsertLeave" then
      b.secrets_edit_row = nil
    end
    mask(ev.buf)
  end,
})
-- the preview of Ctrl+P, search and the explorer hides them too
local ok, preview = pcall(require, "snacks.picker.preview")
if ok and preview.file then
  local file = preview.file
  preview.file = function(ctx, ...)
    local ret = file(ctx, ...)
    local buf = ctx.preview and ctx.preview.win and ctx.preview.win.buf
    local path = ctx.item and (ctx.item.file or "")
    if buf and path ~= "" then
      pcall(mask, buf, path)
    end
    return ret
  end
end

function M.toggle()
  M.enabled = not M.enabled
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      mask(buf)
    end
  end
  vim.notify(M.enabled and "Secrets hidden" or "Secrets visible", vim.log.levels.INFO, { title = "Secrets" })
end
vim.api.nvim_create_user_command("SecretsToggle", M.toggle, { desc = "Show / hide secret values (.env)" })

-- files opened before this loaded (nvim .env)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) then
    mask(buf)
  end
end

return M
