-- "Open Folder" like VS Code: browse the file system folder by folder.
-- Enter on a folder goes inside it, ".." goes up, "Open this folder" opens it.
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

function M.open(dir)
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
          M.open(item.path)
        end
      end)
    end,
  })
end

return M
