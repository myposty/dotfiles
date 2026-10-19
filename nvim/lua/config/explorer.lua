-- The explorer's header, like VS Code's: the project name and the New File,
-- New Folder, Refresh and Collapse buttons, clickable. Same actions from the keyboard
-- inside the explorer: Ctrl+N or a (new file, end with / for a folder), A (new
-- folder). The header is set on the list window in plugins/vscode.lua.
-- Right click opens a menu like VS Code's (New File, Rename, Delete, Cut / Copy /
-- Paste, Copy Path, Reveal in File Explorer, Open in Terminal).
local M = {}

local BUTTONS = {
  { icon = "󰝒", action = "explorer_add", desc = "New File" },
  { icon = "󰉗", action = "explorer_new_folder", desc = "New Folder" },
  { icon = "󰑓", action = "explorer_update", desc = "Refresh" },
  { icon = "󰘕", action = "explorer_close_all", desc = "Collapse Folders" },
}
M.buttons = BUTTONS

local function explorer()
  return Snacks.picker.get({ source = "explorer" })[1]
end

-- winbar click handler: minwid is the button number
function _G.VSCodeExplorerButton(minwid)
  local picker = explorer()
  local button = BUTTONS[minwid]
  if picker and button then
    vim.schedule(function()
      picker:action(button.action)
    end)
  end
end

function M.winbar()
  local picker = explorer()
  local name = vim.fs.basename(picker and picker:cwd() or vim.fn.getcwd()):upper()
  local parts = { "%#VSCodeExplorerTitle# " .. name:gsub("%%", "%%%%") .. "%*%=" }
  for i, b in ipairs(BUTTONS) do
    parts[#parts + 1] = ("%%%d@v:lua.VSCodeExplorerButton@%%#VSCodeExplorerButton# %s %%*%%X"):format(i, b.icon)
  end
  return table.concat(parts) .. " "
end

local function colors()
  vim.api.nvim_set_hl(0, "VSCodeExplorerTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "VSCodeExplorerButton", { link = "Special", default = true })
end
colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

-- Right-click menu, like VS Code's explorer context menu. It acts on the file or
-- folder under the mouse (the cursor moves there first); on empty space, on the
-- project folder.
local ctx = {} -- { picker, item } of the last right click
M.clip = nil -- { paths, cut } from Cut / Copy

local function path_of(item)
  return item and Snacks.picker.util.path(item) or nil
end

local function refresh(picker, target)
  local tree = require("snacks.explorer.tree")
  tree:refresh(picker:cwd())
  if target then
    tree:open(vim.fs.dirname(target))
  end
  require("snacks.explorer.actions").update(picker, { target = target, refresh = true })
end

-- "name.ts" -> "name copy.ts", "name copy 2.ts"... when the name is taken
local function free_name(dir, name)
  local to = vim.fs.joinpath(dir, name)
  local base, ext = name:match("^(.-)(%.[^.]*)$")
  base, ext = base or name, ext or ""
  local n = 1
  while vim.uv.fs_stat(to) do
    to = vim.fs.joinpath(dir, base .. " copy" .. (n > 1 and (" " .. n) or "") .. ext)
    n = n + 1
  end
  return to
end

-- Snacks renames / moves a folder wrongly: it looks the folder up as a buffer-name
-- pattern, which can match some open file, and that file's tab was closed (the start
-- screen showed up). Exact paths here, and open files inside a renamed folder follow
-- it to their new path (unsaved edits are saved first, so nothing is lost).
local function safe_rename(from, to)
  from = vim.fs.normalize(vim.fn.fnamemodify(from, ":p")):gsub("/$", "")
  to = vim.fs.normalize(vim.fn.fnamemodify(to, ":p")):gsub("/$", "")
  local moves = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_is_valid(buf) and vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) or ""
    if name ~= "" and vim.bo[buf].buftype == "" then
      local rest = name == from and "" or (name:sub(1, #from + 1) == from .. "/" and name:sub(#from + 1) or nil)
      if rest then
        moves[#moves + 1] = { buf = buf, to = to .. rest }
      end
    end
  end
  -- saved as they are (no format on save: a rename does not change the code)
  for _, m in ipairs(moves) do
    if vim.api.nvim_buf_is_valid(m.buf) and vim.bo[m.buf].modified then
      vim.api.nvim_buf_call(m.buf, function() vim.cmd("silent! noautocmd write") end)
    end
  end
  -- Windows does not rename a folder while it is watched: the explorer watches every
  -- open folder, so stop those watches first (the explorer starts them again)
  local ok_watch, watch = pcall(require, "snacks.explorer.watch")
  if ok_watch then
    local low = from:lower()
    for path in pairs(watch._watches) do
      local p = vim.fs.normalize(path):lower()
      if p == low or p:sub(1, #low + 1) == low .. "/" then
        watch.stop(path)
      end
    end
  end
  vim.fn.mkdir(vim.fs.dirname(to), "p")
  local err
  -- the closed watches let go of the folder a moment later
  vim.wait(1500, function()
    local ok, e = vim.uv.fs_rename(from, to)
    err = not ok and e or nil
    return ok == true or (e or ""):find("ENOENT") ~= nil -- done, or nothing to retry
  end, 50)
  if err then
    vim.notify("Could not rename " .. from .. "\n" .. err, vim.log.levels.ERROR, { title = "Explorer" })
    return false
  end
  -- forget the old folder now, or the explorer tries to watch it again ("Failed to watch")
  pcall(function()
    local tree = require("snacks.explorer.tree")
    tree:refresh(vim.fs.dirname(from))
    local node = tree:find(from)
    if node then
      node.open = false
    end
  end)
  -- the same buffer takes the new name: its tab keeps its place, undo keeps working
  for _, m in ipairs(vim.tbl_filter(function(x) return vim.api.nvim_buf_is_valid(x.buf) end, moves)) do
    local old = vim.api.nvim_buf_get_name(m.buf)
    vim.api.nvim_buf_set_name(m.buf, m.to)
    vim.api.nvim_buf_call(m.buf, function() vim.cmd("silent! edit!") end)
    -- renaming leaves an empty, unlisted buffer with the old name behind
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if b ~= m.buf and not vim.bo[b].buflisted
        and vim.fs.normalize(vim.api.nvim_buf_get_name(b)) == vim.fs.normalize(old) then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      end
    end
  end
  return true
end
require("snacks.rename")._rename = safe_rename
M.safe_rename = safe_rename

-- Rename (menu, or r in the explorer): only the name, in the same folder, like VS Code
function M.rename(picker, item)
  local from = path_of(item)
  if not from then
    return
  end
  from = vim.fs.normalize(from):gsub("/$", "")
  local old = vim.fs.basename(from)
  Snacks.input({ prompt = "Rename", default = old }, function(name)
    name = name and vim.trim(name) or ""
    if name == "" or name == old then
      return
    end
    local to = vim.fs.joinpath(vim.fs.dirname(from), name)
    if vim.uv.fs_stat(to) and to:lower() ~= from:lower() then
      return vim.notify(name .. " already exists here", vim.log.levels.WARN, { title = "Explorer" })
    end
    Snacks.rename.rename_file({ from = from, to = to }) -- also tells the language servers (imports)
    refresh(picker, to)
  end)
end

local function system_open(args)
  vim.system(args, { detach = true })
end

local ACTIONS = {
  new_file = function(p) p:action("explorer_add") end,
  new_folder = function(p) p:action("explorer_new_folder") end,
  open_side = function(p) p:action("edit_vsplit") end,
  rename = function(p, item) M.rename(p, item) end,
  delete = function(p) p:action("explorer_del") end,
  cut = function(_, item) M.clip = { paths = { path_of(item) }, cut = true } end,
  copy = function(_, item) M.clip = { paths = { path_of(item) }, cut = false } end,
  paste = function(p)
    if not M.clip then
      return vim.notify("Nothing to paste: Cut or Copy a file first", vim.log.levels.WARN, { title = "Explorer" })
    end
    local dir, last = p:dir(), nil
    for _, from in ipairs(M.clip.paths) do
      if M.clip.cut and vim.fs.dirname(from) == dir then
        goto continue -- moving into the folder it is already in
      end
      last = free_name(dir, vim.fs.basename(from))
      if M.clip.cut then
        Snacks.rename.rename_file({ from = from, to = last })
      else
        Snacks.picker.util.copy_path(from, last)
      end
      ::continue::
    end
    if M.clip.cut then
      M.clip = nil -- a cut pastes once, like VS Code
    end
    refresh(p, last)
  end,
  copy_path = function(_, item)
    vim.fn.setreg("+", vim.fs.normalize(path_of(item)))
    vim.notify("Copied " .. vim.fs.normalize(path_of(item)), vim.log.levels.INFO, { title = "Explorer" })
  end,
  copy_relative_path = function(p, item)
    local rel = vim.fs.relpath(p:cwd(), path_of(item)) or path_of(item)
    vim.fn.setreg("+", rel)
    vim.notify("Copied " .. rel, vim.log.levels.INFO, { title = "Explorer" })
  end,
  reveal = function(_, item)
    local path = path_of(item)
    if vim.fn.has("win32") == 1 then
      system_open({ "explorer.exe", "/select," .. path:gsub("/", "\\") })
    elseif vim.fn.has("mac") == 1 then
      system_open({ "open", "-R", path })
    else
      system_open({ "xdg-open", vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path) })
    end
  end,
  terminal = function(p) Snacks.terminal(nil, { cwd = p:dir() }) end,
}
M.actions = ACTIONS

function M.run(name)
  local picker, item = ctx.picker, ctx.item
  if picker and not picker.closed and ACTIONS[name] then
    ACTIONS[name](picker, item)
  end
end

-- the menu for a file or a folder (lua/config/menu.lua shows it)
local function items(is_dir)
  local function act(name)
    return function() M.run(name) end
  end
  local list = { { "New File", act("new_file") }, { "New Folder", act("new_folder") }, "-" }
  if not is_dir then
    list[#list + 1] = { "Open to the Side", act("open_side") }
  end
  vim.list_extend(list, {
    { vim.fn.has("mac") == 1 and "Reveal in Finder" or "Reveal in File Explorer", act("reveal") },
    { "Open in Terminal", act("terminal") },
    "-",
    { "Cut", act("cut") },
    { "Copy", act("copy") },
    { "Paste", act("paste") },
    "-",
    { "Copy Path", act("copy_path") },
    { "Copy Relative Path", act("copy_relative_path") },
    "-",
    { "Rename...", act("rename") },
    { "Delete", act("delete") },
  })
  return list
end

-- right click in the explorer list, from any window
function M.context(picker)
  local pos = vim.fn.getmousepos()
  local list = picker.list
  if pos.winid == list.win.win and pos.line > 0 then
    local topline = vim.api.nvim_win_call(pos.winid, function() return vim.fn.line("w0") end)
    local idx = list:row2idx(pos.line - topline + 1)
    -- empty space below the files: the project folder (the first line)
    list:_move(idx <= list:count() and idx or 1, true, true)
  end
  ctx.picker, ctx.item = picker, picker:current()
  if ctx.item then
    require("config.menu").open(items(ctx.item.dir))
  end
end

table.insert(require("config.scrollbar").on_right_click, function(pos)
  local picker = explorer()
  local win = picker and picker.list and picker.list.win and picker.list.win.win
  if not win or pos.winid ~= win or pos.line < 1 then
    return false
  end
  if vim.fn.mode() == "t" or vim.fn.mode() == "i" then
    vim.cmd.stopinsert()
  end
  vim.api.nvim_set_current_win(win)
  M.context(picker)
  return true
end)

-- Text boxes (new file, new folder, rename...) close when you click or move
-- elsewhere, like VS Code's inline box; before, one left behind stayed on screen
-- and Esc no longer reached it
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("vscode_input_blur", { clear = true }),
  pattern = "snacks_input",
  callback = function(ev)
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer = ev.buf,
      once = true,
      callback = function()
        local win = vim.fn.bufwinid(ev.buf)
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end)
      end,
    })
  end,
})

return M
