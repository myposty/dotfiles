-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Terminals (Claude, shell) are ready to type whenever they get focus, like VS Code
local term_focus = vim.api.nvim_create_augroup("vscode_terminal_focus", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = term_focus,
  callback = function()
    if vim.bo.buftype == "terminal" then
      vim.schedule(function()
        if vim.bo.buftype == "terminal" and vim.fn.mode() ~= "t" then
          vim.cmd.startinsert()
        end
      end)
    end
  end,
})

-- Mouse while typing in a terminal (Claude, shell). Apps like Claude do not use the
-- mouse, so by default any click drops Neovim out of terminal mode and keys stop
-- reaching the app. Instead:
-- * click inside the terminal: ignored, it stays ready to type
-- * drag a divider: the panel is resized here, the terminal stays ready to type
-- * click another panel: leave the terminal and replay the click there
local drag -- { win, kind } while a divider is being dragged

local function divider_at(pos)
  local info = pos.winid ~= 0 and vim.fn.getwininfo(pos.winid)[1] or nil
  if not info then
    return nil
  end
  if pos.wincol == info.width + 1 then
    return { win = pos.winid, kind = "vertical" }
  elseif pos.winrow == info.height + 1 then
    return { win = pos.winid, kind = "horizontal" }
  end
  return nil, info
end

-- Resize pointer (<->) over dividers on macOS and Linux terminals that support
-- OSC 22 (kitty, Ghostty, iTerm2, foot, xterm). Windows drops the sequence (ConPTY).
if vim.fn.has("win32") == 0 then
  vim.o.mousemoveevent = true
  local shape = "default"
  local function pointer(name)
    if name == shape then
      return
    end
    shape = name
    local seq = "\27]22;" .. name .. "\27\\"
    if vim.api.nvim_ui_send then
      vim.api.nvim_ui_send(seq)
    else
      vim.fn.chansend(vim.v.stderr, seq)
    end
  end

  vim.keymap.set({ "n", "i", "v", "t" }, "<MouseMove>", function()
    local divider = divider_at(vim.fn.getmousepos())
    local name = divider and (divider.kind == "vertical" and "ew-resize" or "ns-resize") or "default"
    vim.schedule(function()
      pointer(name)
    end)
    return ""
  end, { expr = true, desc = "Resize pointer over dividers" })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      pointer("default")
    end,
  })
end

-- Side panels (file tree, Claude, side terminals) keep their size; only the middle
-- panel grows or shrinks when the window is resized. A full-width panel (bottom
-- terminal) keeps its height instead.
local function is_side_panel(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  return ft == "snacks_picker_list" or ft == "snacks_layout_box" or vim.bo[buf].buftype == "terminal"
end

local function fix_side_panels()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and is_side_panel(win) then
      local full_width = vim.api.nvim_win_get_width(win) >= vim.o.columns - 1
      vim.wo[win].winfixwidth = not full_width
      vim.wo[win].winfixheight = full_width
    end
  end
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "TermOpen", "WinNew" }, {
  group = vim.api.nvim_create_augroup("vscode_fixed_side_panels", { clear = true }),
  callback = function()
    vim.schedule(fix_side_panels)
  end,
})

-- Dragging a divider resizes only the two panels that touch it, so the file tree
-- never shrinks when the editor/Claude divider moves. Works from any panel,
-- including terminals, which stay ready to type.
local function neighbor_of(info, kind)
  for _, w in ipairs(vim.fn.getwininfo()) do
    if w.tabnr == info.tabnr and vim.api.nvim_win_get_config(w.winid).relative == "" then
      if kind == "vertical" and w.wincol == info.wincol + info.width + 1
        and w.winrow < info.winrow + info.height and w.winrow + w.height > info.winrow then
        return w.winid
      elseif kind == "horizontal" and w.winrow == info.winrow + info.height + 1
        and w.wincol < info.wincol + info.width and w.wincol + w.width > info.wincol then
        return w.winid
      end
    end
  end
end

local function resize_to(pos)
  if not (drag and vim.api.nvim_win_is_valid(drag.win)) then
    return
  end
  local info = vim.fn.getwininfo(drag.win)[1]
  local other = neighbor_of(info, drag.kind)
  for _, w in ipairs({ drag.win, other }) do
    if w then
      vim.wo[w].winfixwidth = false
      vim.wo[w].winfixheight = false
    end
  end
  if drag.kind == "vertical" then
    vim.api.nvim_win_set_width(drag.win, math.max(pos.screencol - info.wincol, 1))
  else
    vim.api.nvim_win_set_height(drag.win, math.max(pos.screenrow - info.winrow, 1))
  end
  fix_side_panels()
end

-- Mouse while typing in a terminal (Claude, shell). Apps like Claude do not use the
-- mouse, so by default any click drops Neovim out of terminal mode and keys stop
-- reaching the app. Instead a click inside the terminal is ignored (it stays ready
-- to type) and a click on another panel switches to it.
vim.keymap.set({ "n", "t" }, "<LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  local divider, info = divider_at(pos)
  if divider then
    drag = divider
    return ""
  end
  if vim.fn.mode() ~= "t" then
    -- Normal mode: a click inside a terminal makes it ready to type again
    if info and vim.bo[vim.api.nvim_win_get_buf(pos.winid)].buftype == "terminal" then
      vim.schedule(function()
        if vim.bo.buftype == "terminal" and vim.fn.mode() ~= "t" then
          vim.cmd.startinsert()
        end
      end)
    end
    return "<LeftMouse>"
  end
  if info and pos.winid ~= vim.api.nvim_get_current_win() then
    -- Windows cannot change inside an expr mapping, so switch right after it
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(pos.winid) then
        vim.api.nvim_set_current_win(pos.winid)
        if pos.line > 0 then
          pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, math.max(pos.column - 1, 0) })
        end
      end
    end)
  end
  return ""
end, { expr = true, desc = "Click" })

vim.keymap.set({ "n", "t" }, "<LeftDrag>", function()
  if drag then
    local pos = vim.fn.getmousepos()
    vim.schedule(function()
      resize_to(pos)
    end)
    return ""
  end
  return vim.fn.mode() == "t" and "" or "<LeftDrag>"
end, { expr = true, desc = "Drag a divider" })

vim.keymap.set({ "n", "t" }, "<LeftRelease>", function()
  if drag then
    drag = nil
    return ""
  end
  return vim.fn.mode() == "t" and "" or "<LeftRelease>"
end, { expr = true, desc = "Stop dragging" })

-- Like VS Code: with no file open, the middle panel shows the start screen
-- (open folder, shortcuts, git). It comes back after opening a folder or closing
-- the last file, and refreshes when the folder changes.
local function no_files_open()
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.name ~= "" then
      return false
    end
  end
  return true
end

local function show_start_screen()
  if not no_files_open() then
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "snacks_dashboard" then
      return
    end
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local empty = vim.api.nvim_buf_get_name(buf) == "" and vim.bo[buf].buftype == ""
      and vim.bo[buf].filetype == "" and not vim.bo[buf].modified
      and vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
    if empty and vim.api.nvim_win_get_config(win).relative == "" then
      Snacks.dashboard({ win = win, buf = buf })
      return
    end
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufDelete", "DirChanged" }, {
  group = vim.api.nvim_create_augroup("vscode_start_screen", { clear = true }),
  callback = function(ev)
    vim.schedule(function()
      show_start_screen()
      if ev.event == "DirChanged" then
        Snacks.dashboard.update()
      end
    end)
  end,
})

-- Name on the start screen: ask once per machine, change it with :SetName
vim.api.nvim_create_user_command("SetName", function(args)
  if args.args ~= "" then
    require("config.logo").set_name(args.args)
  else
    require("config.logo").ask()
  end
end, { nargs = "?", desc = "Change the name on the start screen" })

if require("config.logo").get_name() == nil and #vim.api.nvim_list_uis() > 0 then
  vim.schedule(function()
    require("config.logo").ask(true)
  end)
end
