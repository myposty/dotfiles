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

-- Reopen a session the way VS Code reopens a workspace. Never discards unsaved work.
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
  end)
  if not ok then
    vim.notify("Could not open the session: " .. tostring(err), vim.log.levels.ERROR)
  end
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

return M
