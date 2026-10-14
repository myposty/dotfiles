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

-- Git Bash / MSYS paths on Windows: /c/Users/... is C:/Users/...
local function from_msys(path)
  if vim.fn.has("win32") == 1 then
    return (path:gsub("^/(%a)/", "%1:/"))
  end
  return path
end

-- `dirs`: folders the output was talking about (a `cd "..."` above the click),
-- tried before the current folder
function M.resolve(text, cwd, dirs)
  cwd = clean(cwd)
  -- ~\ or ~/ is the home folder (expand() would also eat \ and treat % and # as names)
  text = from_msys(clean(text):gsub("^~/", function() return clean(vim.uv.os_homedir()) .. "/" end))
  local base = text:match("[^/…]+$")
  if not base or vim.fn.isdirectory(text) == 1 then
    return nil
  end
  local head, tail = text:match("^(.-)…(.*)$")
  if not head then
    if is_absolute(text) then
      return vim.fn.filereadable(text) == 1 and vim.fs.normalize(text) or nil
    end
    for _, dir in ipairs(vim.list_extend(vim.deepcopy(dirs or {}), { cwd })) do
      local full = clean(dir) .. "/" .. text
      if vim.fn.filereadable(full) == 1 then
        return vim.fs.normalize(full)
      end
    end
    -- printed relative to another folder: find a file ending with the same path
    -- (a bare name only when the output gave no folder, closest match wins)
    if text:find("/") then
      return search(cwd, base, function(f) return vim.endswith(f, "/" .. text) end)
    end
    return search(cwd, base, function(f) return vim.fs.basename(f) == base end)
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
  -- video, PDF, Excel... (and images where the terminal cannot draw them): system app
  local files = require("config.images")
  if files.is_external(path) then
    files.open_external(path)
    return
  end
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

-- Paths inside Claude's tool lines, Update(...) / Read(...) / Write(...): any file,
-- with or without extension, spaces included. "Read(a.lua · lines 1-20)" gives a.lua.
local function tool_paths(line)
  local found = {}
  for inner in line:gmatch("%u%a+%(([^()]+)%)") do
    inner = vim.trim(inner)
    found[#found + 1] = inner
    local first = inner:match("^(.-)%s+·") or inner:match("^(%S+)%s")
    if first then
      found[#found + 1] = first
    end
  end
  return found
end

-- Paths in the lines Claude puts above a diff: Update(path) / Read(path · lines 1-20)
-- and "⎿  Updated path (+1 -2)"
local function header_paths(line)
  local found = tool_paths(line)
  local changed = line:match("%u%a+%s+(%S+)%s+%(%+%d+")
  if changed then
    found[#found + 1] = changed
  end
  return found
end

local function rtrim(s) return (s:gsub("%s+$", "")) end
local function ltrim(s) return (s:gsub("^%s+", "")) end

-- Claude wraps long lines to the terminal width, so a path can be split in two
-- ("...views\outbou" + "nd\promo.ts"). The text of a line joined with the next one,
-- and where the join is.
local function joined(a, b)
  local left = rtrim(a or "")
  return left .. ltrim(b or ""), #left
end

-- Open the file named at a mouse position (vim.fn.getmousepos()). True when it did.
-- In order: the path under the click (also when wrapped onto two lines), the file of
-- a Claude header line, the file and line of a diff line, any other path on the line.
function M.open_at(pos)
  if pos.winid == 0 or pos.line < 1 then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype ~= "terminal" then
    return false
  end
  local cwd = vim.fn.getcwd(pos.winid)
  local n = pos.line
  local lines = vim.api.nvim_buf_get_lines(buf, math.max(n - 301, 0), n + 1, false)
  local at = math.min(n, 301) -- index of the clicked line in `lines`
  local line, prev, next = lines[at] or "", lines[at - 1], lines[at + 1]
  local col = vim.str_byteindex(line, "utf-32", math.max(pos.column - 1, 0), false) + 1

  -- folders the output talked about, nearest first: `cd "C:/x"`, `cd '/c/x'`, `cd x`
  -- (Claude's Bash lines), so a bare file name printed below one is found there
  local dirs = {}
  for i = at, math.max(at - 80, 1), -1 do
    local l = lines[i] or ""
    for dir in l:gmatch("cd%s+\"([^\"]+)\"") do
      dirs[#dirs + 1] = dir
    end
    for dir in l:gmatch("cd%s+'([^']+)'") do
      dirs[#dirs + 1] = dir
    end
    for dir in l:gmatch("cd%s+([^%s\"';&|]+)") do
      dirs[#dirs + 1] = dir
    end
  end
  dirs = vim.tbl_map(function(d)
    d = from_msys(clean(d))
    return is_absolute(d) and d or (clean(cwd) .. "/" .. d)
  end, dirs)

  local function try(text, lnum)
    local path = M.resolve(text, cwd, dirs)
    if path then
      vim.schedule(function() open(path, lnum) end)
      return true
    end
  end

  -- 1. the path under the click, whole or split across this line and a neighbour
  local here = tokens(line)
  for _, t in ipairs(here) do
    if col >= t.s and col <= t.e and try(t.text, t.lnum) then
      return true
    end
  end
  for _, pair in ipairs({ { prev, line }, { line, next } }) do
    if pair[1] and pair[2] then
      local text, join = joined(pair[1], pair[2])
      for _, t in ipairs(tokens(text)) do
        if t.s <= join and t.e > join and try(t.text, t.lnum) then
          return true
        end
      end
    end
  end

  -- 2. a header line names the file
  for _, h in ipairs(header_paths(line)) do
    if try(h) then
      return true
    end
  end

  -- 3. a diff line opens its file at that line; a wrapped diff line (no number of
  -- its own) belongs to the numbered line above it
  local lnum, from = tonumber(line:match("^%s*(%d+)%s")), at
  if not lnum and line:match("^%s+%S") then
    for i = at - 1, math.max(at - 8, 1), -1 do
      lnum = tonumber(lines[i]:match("^%s*(%d+)%s"))
      if lnum or #header_paths(lines[i]) > 0 then
        from = i
        break
      end
    end
  end
  if lnum then
    for i = from - 1, 1, -1 do
      local names = header_paths(lines[i])
      if #names == 0 and lines[i + 1] then
        names = header_paths((joined(lines[i], lines[i + 1])))
      end
      if #names > 0 then
        for _, name in ipairs(names) do
          if try(name, lnum) then
            return true
          end
        end
        break
      end
    end
  end

  -- 4. any other path on the line, closest to the click first
  table.sort(here, function(a, b)
    return math.min(math.abs(col - a.s), math.abs(col - a.e)) < math.min(math.abs(col - b.s), math.abs(col - b.e))
  end)
  for _, t in ipairs(here) do
    if try(t.text, t.lnum) then
      return true
    end
  end
  return false
end

return M
