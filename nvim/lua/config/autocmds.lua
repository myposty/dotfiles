-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Files open ready to type, like VS Code: letters write text instead of running
-- Vim commands. Esc still switches to Vim's command mode for those who want it.
local function is_file_buffer(buf)
  return vim.bo[buf].buftype == "" and vim.bo[buf].modifiable and not vim.bo[buf].readonly
    and vim.bo[buf].filetype ~= "snacks_dashboard" and vim.api.nvim_buf_get_name(buf) ~= ""
end

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = vim.api.nvim_create_augroup("vscode_type_in_files", { clear = true }),
  callback = function(ev)
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      if buf == ev.buf and is_file_buffer(buf) and vim.fn.mode() == "n"
        and vim.api.nvim_win_get_config(0).relative == "" then
        vim.cmd.startinsert()
      end
    end)
  end,
})

-- A terminal scrolled up to read its history: getting ready to type would jump to
-- the bottom, so clicks and focus leave it where it is (like VS Code)
local function terminal_scrolled_up(win)
  win = win or 0
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "terminal" and vim.fn.line("w$", win) < vim.api.nvim_buf_line_count(buf)
end

-- Terminals (Claude, shell) are ready to type whenever they get focus, like VS Code
local term_focus = vim.api.nvim_create_augroup("vscode_terminal_focus", { clear = true })
-- Leaving a scrolled-up terminal remembers where it was: coming back from a file that
-- is being typed in enters terminal mode by itself, which jumps to the bottom
vim.api.nvim_create_autocmd("WinLeave", {
  group = term_focus,
  callback = function()
    vim.w.term_view = terminal_scrolled_up() and vim.fn.winsaveview() or nil
  end,
})
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = term_focus,
  callback = function()
    local view = vim.w.term_view
    if vim.bo.buftype == "terminal" and view then
      vim.w.term_view = nil
      vim.w.term_restoring = true
      local win = vim.api.nvim_get_current_win()
      -- terminal mode starts after these autocmds: leave it, then put the view back
      vim.defer_fn(function()
        if vim.api.nvim_get_current_win() == win and vim.fn.mode() == "t" then
          vim.cmd.stopinsert()
        end
        vim.defer_fn(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
            vim.w[win].term_restoring = nil
          end
        end, 30)
      end, 30)
      return
    end
    -- an image tab (config/images.lua) is a picture, not something to type into
    if vim.bo.buftype == "terminal" and not vim.w.term_restoring and not vim.b.image_view then
      vim.schedule(function()
        if vim.bo.buftype == "terminal" and vim.fn.mode() ~= "t" and not terminal_scrolled_up() and not vim.b.image_view then
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
  return ft == "snacks_picker_list" or ft == "snacks_layout_box" or ft == "vscode_scm" or vim.bo[buf].buftype == "terminal"
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

-- Clicks while typing in a terminal (Claude, shell). Apps like Claude do not use the
-- mouse, so by default any click drops Neovim out of terminal mode and keys stop
-- reaching the app. Instead a click inside the terminal is ignored (it stays ready
-- to type), a click on another panel switches to it, and a divider can be dragged.
-- These mappings are terminal-only: in the editor the mouse stays native, so text
-- selection by dragging works.
vim.keymap.set("t", "<LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  local divider, info = divider_at(pos)
  if divider then
    drag = divider
    return ""
  end
  -- a file path (or a numbered diff line) under the click opens in the editor
  if require("config.links").open_at(pos) then
    return ""
  end
  if info and pos.winid ~= vim.api.nvim_get_current_win() then
    -- Windows cannot change inside an expr mapping, so switch right after it
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(pos.winid) then
        vim.api.nvim_set_current_win(pos.winid)
        if pos.line > 0 then
          pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, math.max(pos.column - 1, 0) })
        end
        -- terminal mode ends after this callback, so check once it has
        vim.defer_fn(function()
          if is_file_buffer(vim.api.nvim_get_current_buf()) and vim.fn.mode() == "n" then
            vim.cmd.startinsert()
          end
        end, 20)
      end
    end)
  end
  return ""
end, { expr = true, desc = "Click from a terminal" })

vim.keymap.set("t", "<LeftDrag>", function()
  if drag then
    local pos = vim.fn.getmousepos()
    vim.schedule(function()
      resize_to(pos)
    end)
  end
  return ""
end, { expr = true, desc = "Drag a divider from a terminal" })

vim.keymap.set("t", "<LeftRelease>", function()
  drag = nil
  return ""
end, { expr = true, desc = "Stop dragging" })

-- Outside terminals Neovim handles the mouse itself; this only observes it:
-- * pressing on a divider frees the two panels that touch it, so the native drag
--   resizes them while the other side panels keep their width
-- * releasing restores the fixed side panels, and a click that ends inside a
--   terminal makes it ready to type again
local left_mouse, left_release = vim.keycode("<LeftMouse>"), vim.keycode("<LeftRelease>")
vim.on_key(function(_, typed)
  if typed == left_mouse and vim.fn.mode() ~= "t" then
    local divider = divider_at(vim.fn.getmousepos())
    if divider then
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(divider.win) then
          return
        end
        local other = neighbor_of(vim.fn.getwininfo(divider.win)[1], divider.kind)
        for _, w in ipairs({ divider.win, other }) do
          if w then
            vim.wo[w].winfixwidth = false
            vim.wo[w].winfixheight = false
          end
        end
      end)
    end
  elseif typed == left_release then
    local pos = vim.fn.getmousepos()
    vim.schedule(function()
      -- a click on a file path in a terminal that was not focused opens the file
      if vim.fn.mode() == "n" and require("config.links").open_at(pos) then
        return
      end
      fix_side_panels()
      local buf = vim.api.nvim_get_current_buf()
      local typable = vim.bo[buf].buftype == "terminal" or is_file_buffer(buf)
      -- a click (not a drag selection) leaves terminals and files ready to type
      if typable and vim.fn.mode() == "n" and not terminal_scrolled_up() then
        vim.cmd.startinsert()
      end
    end)
  end
end, vim.api.nvim_create_namespace("vscode_mouse"))

-- Typing in a terminal scrolled up (or not ready to type) goes back to the bottom and
-- the key reaches the app, like VS Code: letters never run Vim commands there
vim.api.nvim_create_autocmd("TermOpen", {
  group = term_focus,
  callback = function(ev)
    if vim.b[ev.buf].image_view then
      return -- an image tab has nothing to type into
    end
    local keys = { "<Space>", "<CR>", "<BS>" }
    for b = 33, 126 do
      keys[#keys + 1] = b == 60 and "<lt>" or string.char(b)
    end
    for _, key in ipairs(keys) do
      vim.keymap.set("n", key, "i" .. key, { buffer = ev.buf, nowait = true })
    end
  end,
})

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

-- Keep the git status on the start screen current: after lazygit or any terminal
-- closes, when coming back to the window, and when the start screen gets focus
vim.api.nvim_create_autocmd({ "TermClose", "FocusGained", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("vscode_start_screen_git", { clear = true }),
  callback = function(ev)
    if ev.event == "BufEnter" and vim.bo[ev.buf].filetype ~= "snacks_dashboard" then
      return
    end
    vim.defer_fn(function()
      pcall(Snacks.dashboard.update)
    end, 100)
  end,
})

-- The start screen always fits the window (see plugins/vscode.lua), but Vim still lets
-- the wheel and Ctrl+E/Y push the last line up to the top; there is nothing to scroll to
local function lock_start_screen(buf)
  for _, key in ipairs({ "<ScrollWheelUp>", "<ScrollWheelDown>", "<C-e>", "<C-y>" }) do
    vim.keymap.set({ "n", "v" }, key, "<Nop>", { buffer = buf })
  end
end
-- The start screen opens before this file loads, so lock the one already open too
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == "snacks_dashboard" then
    lock_start_screen(buf)
  end
end
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("vscode_start_screen_noscroll", { clear = true }),
  pattern = "snacks_dashboard",
  callback = function(ev) lock_start_screen(ev.buf) end,
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

-- Source control panel that opens with the file explorer (lua/config/scm.lua)
require("config.scm")

-- Update check for the dotfiles repo on start (lua/config/updates.lua)
require("config.updates")
require("config.markdown")

-- Recent sessions: start screen list and :Sessions (lua/config/sessions.lua).
-- The explorer opens when a project is chosen (a recent session, or a folder from
-- Ctrl+Shift+O / Ctrl+Shift+K), not when nvim starts.
require("config.sessions")

-- Image files: system viewer where the terminal cannot show them (lua/config/images.lua)
require("config.images")
