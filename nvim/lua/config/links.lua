-- Clickable file paths in terminals (Claude, shell), like links in the VS Code terminal.
-- Clicking a line that names a file opens it in the editor. Paths may be relative to the
-- current folder, use \ or /, end in :line, or be shortened by Claude with "…"
-- (ElSegundoSilbido\doc…\notes.md). Clicking a numbered line of a diff that Claude
-- shows under Update(file) / Write(file) opens that file at that line.
local M = {}

-- name.ext with a letter after the dot, so numbers like 82.5 are not paths
local PATH = "[%w%._%-/\\~:…]+%.%a%w*"
-- A click must never freeze the editor: bounded file search
local SEARCH_MS, SEARCH_DEPTH = 1500, 12

local function clean(path)
  return (path:gsub("\\", "/"):gsub("^%./", ""))
end

-- Every path-looking token on a line, with the column range it covers
local function tokens(line)
  local found, init = {}, 1
  while true do
    local s, e = line:find(PATH, init)
    if not s then
      return found
    end
    local text = line:sub(s, e)
    local lnum = line:sub(e + 1):match("^:(%d+)")
    found[#found + 1] = { text = text, s = s, e = e, lnum = tonumber(lnum) }
    init = e + 1
  end
end

local function search(start, base, ok)
  local files = {}
  if vim.fn.executable("rg") == 1 then
    local ok, res = pcall(function()
      return vim.system({ "rg", "--files", "--hidden", "--no-messages", "--max-depth", tostring(SEARCH_DEPTH),
        "-g", "**/" .. base, start }, { text = true, timeout = SEARCH_MS }):wait()
    end)
    if ok and res.stdout then
      files = vim.split(res.stdout, "\n", { trimempty = true })
    end
  end
  for _, f in ipairs(files) do
    f = clean(f)
    if ok(f) then
      return f
    end
  end
end

-- The real file for a path as printed in the terminal, or nil
local function is_absolute(path)
  return path:match("^/") ~= nil or path:match("^%a:/") ~= nil
end

function M.resolve(text, cwd)
  cwd = clean(cwd)
  text = clean(vim.fn.expand(text))
  local base = text:match("[^/…]+$")
  if not base then
    return nil
  end
  local head, tail = text:match("^(.-)…(.*)$")
  if not head then
    local full = is_absolute(text) and text or (cwd .. "/" .. text)
    if vim.fn.filereadable(full) == 1 then
      return vim.fs.normalize(full)
    end
    -- printed relative to another folder: find a file ending with the same path
    if not text:find("/") then
      return nil
    end
    return search(cwd, base, function(f) return vim.endswith(f, "/" .. text) end)
  end
  -- shortened: search from the deepest folder that the visible start names
  local dir = head:match("^(.*)/") or ""
  local start = is_absolute(head) and dir or (cwd .. "/" .. dir)
  if dir == "" or vim.fn.isdirectory(start) == 0 then
    start = cwd
  end
  local prefix = start == cwd and head or (start .. head:sub(#dir + 1))
  return search(start, base, function(f)
    local abs = is_absolute(f) and f or (start .. "/" .. f)
    local rel = vim.startswith(abs, cwd .. "/") and abs:sub(#cwd + 2) or abs
    return (vim.startswith(abs, prefix) or vim.startswith(rel, prefix)) and vim.endswith(abs, tail)
  end)
end

-- The main editor window (not a terminal or side panel); made if there is none
local function editor_window()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    local ft = vim.bo[b].filetype
    if vim.api.nvim_win_get_config(w).relative == "" and vim.bo[b].buftype ~= "terminal"
      and (not ft:match("^snacks_") or ft == "snacks_dashboard") and ft ~= "vscode_scm" then
      return w
    end
  end
  vim.cmd("topleft vnew")
  return vim.api.nvim_get_current_win()
end

local function open(path, lnum)
  local win = editor_window()
  vim.api.nvim_set_current_win(win)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if lnum then
    pcall(vim.api.nvim_win_set_cursor, win, { math.min(lnum, vim.api.nvim_buf_line_count(0)), 0 })
    vim.cmd("normal! zz")
  end
  -- ready to type, like any file (the terminal click may end in normal mode)
  vim.defer_fn(function()
    if vim.fn.mode() == "n" and vim.bo.buftype == "" and vim.bo.modifiable then
      vim.cmd.startinsert()
    end
  end, 80)
end

-- Open the file named at a mouse position (vim.fn.getmousepos()). True when it did.
function M.open_at(pos)
  if pos.winid == 0 or pos.line < 1 then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype ~= "terminal" then
    return false
  end
  local cwd = vim.fn.getcwd(pos.winid)
  local line = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1] or ""
  local col = vim.str_byteindex(line, "utf-32", math.max(pos.column - 1, 0), false) + 1

  local found = tokens(line)
  table.sort(found, function(a, b)
    local da = (col >= a.s and col <= a.e) and 0 or math.min(math.abs(col - a.s), math.abs(col - a.e))
    local db = (col >= b.s and col <= b.e) and 0 or math.min(math.abs(col - b.s), math.abs(col - b.e))
    return da < db
  end)
  for _, t in ipairs(found) do
    local path = M.resolve(t.text, cwd)
    if path then
      vim.schedule(function() open(path, t.lnum) end)
      return true
    end
  end

  -- a numbered diff line: the file is in the Update(...) / Write(...) line above it
  local lnum = tonumber(line:match("^%s*(%d+)%s"))
  if lnum then
    local first = math.max(pos.line - 300, 1)
    local above = vim.api.nvim_buf_get_lines(buf, first - 1, pos.line - 1, false)
    for i = #above, 1, -1 do
      local name = above[i]:match("%u%l+%((" .. PATH .. ")%)")
      if name then
        local path = M.resolve(name, cwd)
        if path then
          vim.schedule(function() open(path, lnum) end)
          return true
        end
        break
      end
    end
  end
  return false
end

return M
