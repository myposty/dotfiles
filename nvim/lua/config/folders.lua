-- "Open Folder" like VS Code: search every folder by name (M.open) or browse the
-- file system folder by folder (M.browse).
local M = {}

local function list(dir)
  local items = { { text = "Open this folder", kind = "open", path = dir } }
  local parent = vim.fs.dirname(dir)
  if parent and parent ~= dir then
    items[#items + 1] = { text = "..", kind = "up", path = parent }
  end
  local names = {}
  for name, type in vim.fs.dir(dir) do
    local path = vim.fs.joinpath(dir, name)
    if name ~= ".git" and (type == "directory" or (type == "link" and vim.fn.isdirectory(path) == 1)) then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    return a:lower() < b:lower()
  end)
  for _, name in ipairs(names) do
    items[#items + 1] = { text = name, kind = "dir", path = vim.fs.joinpath(dir, name) }
  end
  return items
end

-- Switch the editor to the folder and show its file tree
function M.use(dir)
  vim.cmd.cd(vim.fn.fnameescape(dir))
  Snacks.explorer.open({ cwd = dir })
end

-- Folders that are never worth opening (system, caches, dependencies)
local SKIP = { "node_modules", ".git", "Library", "AppData", "Applications", ".cache", ".npm", ".cargo",
  ".rustup", ".local", "go", "vendor", "dist", "build", "Intermediate", "DerivedDataCache", "Saved", "Binaries" }

-- Ctrl+Shift+K: type part of a folder name and pick it from every folder under home
-- (like VS Code's Open Folder with search). Needs fd; without it, browse step by step.
function M.open(dir)
  if dir or vim.fn.executable("fd") == 0 then
    return M.browse(dir)
  end
  local home = vim.fs.normalize(vim.uv.os_homedir())
  local args = { "--type", "d", "--max-depth", "6", "--color", "never", "--absolute-path" }
  for _, name in ipairs(SKIP) do
    vim.list_extend(args, { "--exclude", name })
  end
  vim.list_extend(args, { ".", home })
  Snacks.picker({
    title = "Open folder (type its name)",
    finder = function(opts, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = "fd",
          args = args,
          transform = function(item)
            item.file = vim.fs.normalize(item.text)
            item.text = vim.fn.fnamemodify(item.file, ":~")
            item.dir = true
          end,
        }),
        ctx
      )
    end,
    layout = { preset = "select" },
    format = function(item)
      return { { "  " .. item.text, "SnacksPickerDirectory" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function() M.use(item.file) end)
      end
    end,
  })
end

-- Folder by folder: Enter goes inside, ".." goes up, "Open this folder" opens it
function M.browse(dir)
  dir = vim.fs.normalize(dir or vim.fn.getcwd())
  Snacks.picker({
    title = "Open folder  " .. vim.fn.fnamemodify(dir, ":~"),
    items = list(dir),
    layout = { preset = "select" },
    format = function(item)
      if item.kind == "open" then
        return { { "  Open this folder", "SnacksPickerSpecial" } }
      elseif item.kind == "up" then
        return { { "  ..", "SnacksPickerComment" } }
      end
      return { { "  " .. item.text .. "/", "SnacksPickerDirectory" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.schedule(function()
        if item.kind == "open" then
          M.use(item.path)
        else
          M.browse(item.path)
        end
      end)
    end,
  })
end

return M
