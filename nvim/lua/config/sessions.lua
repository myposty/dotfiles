-- Recent sessions on the start screen, like VS Code's recent workspaces.
-- LazyVim's persistence.nvim saves one session per folder (and git branch) on exit;
-- this module lists them, filters out junk folders and reopens one.
local M = {}

local function norm(p)
  return (vim.fs.normalize(p):gsub("/+$", "")):lower()
end

local function inside(dir, root)
  dir, root = norm(dir), norm(root)
  return dir == root or dir:sub(1, #root + 1) == root .. "/"
end

-- Folders that are never a project: temp dir and nvim's own data/state/cache
local function ignored_roots()
  local roots = { vim.uv.os_tmpdir() }
  for _, what in ipairs({ "data", "state", "cache" }) do
    roots[#roots + 1] = vim.fn.stdpath(what)
  end
  return vim.tbl_filter(function(r) return r and r ~= "" end, roots)
end

-- Same decoding as persistence.select (session file name -> folder and branch)
local function decode(file)
  local base = vim.fn.fnamemodify(file, ":t"):gsub("%.vim$", "")
  local dir, branch = unpack(vim.split(base, "%%", { plain = true }))
  dir = dir:gsub("%%", "/")
  if vim.fn.has("win32") == 1 then
    dir = dir:gsub("^(%w)/", "%1:/")
  end
  -- the branch name had its "/" saved as "%" too (feat%botflow = feat/botflow)
  return dir, branch and (branch:gsub("%%", "/")) or nil
end

function M.list(max)
  local ok, files = pcall(function()
    if not package.loaded["persistence"] then
      require("lazy").load({ plugins = { "persistence.nvim" } })
    end
    return require("persistence").list()
  end)
  if not ok or type(files) ~= "table" then
    return {}
  end
  local roots = ignored_roots()
  local out, seen = {}, {}
  for _, file in ipairs(files) do
    local good, dir, branch = pcall(decode, file)
    if good and dir and dir ~= "" and vim.fn.isdirectory(dir) == 1 then
      local skip = false
      for _, root in ipairs(roots) do
        if inside(dir, root) then
          skip = true
          break
        end
      end
      local key = norm(dir) .. "%%" .. (branch or "")
      if not skip and not seen[key] then
        seen[key] = true
        local stat = vim.uv.fs_stat(file)
        out[#out + 1] = {
          file = file,
          dir = dir,
          branch = branch,
          name = vim.fn.fnamemodify(dir, ":t") ~= "" and vim.fn.fnamemodify(dir, ":t") or dir,
          mtime = stat and stat.mtime.sec or 0,
        }
        if max and #out >= max then
          break
        end
      end
    end
  end
  return out
end

-- A buffer that does not belong in a session: its file is gone, or it lives in a
-- temp / nvim data folder (a scratch file opened once must not come back forever)
local function junk(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then
    return false
  end
  if vim.fn.filereadable(name) == 0 then
    return true
  end
  for _, root in ipairs(ignored_roots()) do
    if inside(name, root) then
      return true
    end
  end
  return false
end

local function drop_junk()
  -- the files nvim was started with are a one-off, not part of the workspace
  vim.cmd("silent! %argdelete")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and not vim.bo[buf].modified and junk(buf) then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

-- before persistence writes a session, leave the junk out
vim.api.nvim_create_autocmd("User", {
  pattern = "PersistenceSavePre",
  group = vim.api.nvim_create_augroup("vscode_sessions", { clear = true }),
  callback = drop_junk,
})

local function has_files()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
      return true
    end
  end
  return false
end

-- Reopen a session the way VS Code reopens a workspace: the folder with its explorer
-- and the files that still exist; with no files, the start screen of that folder.
-- Never discards unsaved work.
function M.open(item)
  if not item then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].modified then
      vim.notify("Save or discard your changes before opening a session", vim.log.levels.WARN)
      return
    end
  end
  local ok, err = pcall(function()
    vim.cmd("silent! %bwipeout!")
    vim.fn.chdir(item.dir)
    vim.cmd("silent! source " .. vim.fn.fnameescape(item.file))
    drop_junk()
    -- a session opened from here is a workspace again: keep saving it
    if vim.env.NVIM_NO_SESSION ~= "1" then
      require("persistence").start()
    end
  end)
  if not ok then
    vim.notify("Could not open the session: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.schedule(function()
    pcall(function() Snacks.explorer.open() end)
    -- no files: the start screen of that folder (the start screen autocmd may
    -- already have opened it)
    vim.defer_fn(function()
      local shown = false
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_dashboard" then
          shown = true
        end
      end
      if not has_files() and not shown then
        pcall(function() Snacks.dashboard() end)
      end
    end, 150)
  end)
end

function M.restore_last()
  local last = M.list(1)[1]
  if last then
    M.open(last)
  end
end

function M.pick()
  local items = {}
  for _, s in ipairs(M.list(50)) do
    s.text = s.name .. " " .. s.dir .. " " .. (s.branch or "")
    items[#items + 1] = s
  end
  if #items == 0 then
    vim.notify("No saved sessions yet (they are saved when you quit)", vim.log.levels.INFO)
    return
  end
  Snacks.picker({
    title = "Sessions",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      local parts = {
        { ("%-20s "):format(item.name), "SnacksPickerLabel" },
        { vim.fn.fnamemodify(item.dir, ":~"), "SnacksPickerComment" },
      }
      if item.branch then
        parts[#parts + 1] = { " (" .. item.branch .. ")", "SnacksPickerSpecial" }
      end
      return parts
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function() M.open(item) end)
      end
    end,
  })
end

vim.api.nvim_create_user_command("Sessions", M.pick, { desc = "Reopen a recent session" })

-- Like VS Code: a folder opened as a workspace (`nvim`, no files) keeps its session;
-- `nvim notes.txt` is a quick edit and must not replace the folder's session.
-- NVIM_NO_SESSION=1 never saves (scripts, tests).
if vim.fn.argc(-1) > 0 or vim.env.NVIM_NO_SESSION == "1" then
  pcall(function()
    require("lazy").load({ plugins = { "persistence.nvim" } })
    require("persistence").stop()
  end)
end

return M
