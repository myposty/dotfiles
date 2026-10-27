-- Scrollbar for the panels satellite.nvim leaves out: terminals (Claude, shells) and
-- the file explorer list. A one-column strip on the right edge of the panel; the
-- lighter part is the slice on screen. It follows scrolling, resizing and new output,
-- and can be clicked or dragged like VS Code's (the click never reaches the panel).
local M = {}

local bars = {} -- target window -> { win = bar window, buf = bar buffer }
local ns = vim.api.nvim_create_namespace("vscode_scrollbar")

local function colors()
  -- one soft gray for every bar, like VS Code's scrollbar slider (satellite's bar in
  -- code windows included)
  vim.api.nvim_set_hl(0, "ScrollbarThumb", { bg = "#4a4e52" })
  vim.api.nvim_set_hl(0, "SatelliteBar", { link = "ScrollbarThumb" })
end
colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

-- The Snacks picker whose list is shown in `win` (the explorer draws only what fits)
local function picker_of(win)
  for _, picker in ipairs(Snacks and Snacks.picker and Snacks.picker.get() or {}) do
    if picker.list and picker.list.win and picker.list.win.win == win then
      return picker
    end
  end
end

-- What the bar needs to know about a panel, and how to scroll it to a first line
local function metrics(win)
  if not vim.api.nvim_win_is_valid(win) then
    return nil
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.b[buf].image_view then
    return nil
  end
  if vim.bo[buf].filetype == "snacks_picker_list" then
    local picker = picker_of(win)
    if not picker then
      return nil
    end
    local list = picker.list
    return {
      total = list:count(), top = list.top, height = list:height(),
      scroll = function(top) list:_scroll(top, true) end,
    }
  end
  if vim.bo[buf].buftype ~= "terminal" then
    return nil
  end
  return {
    total = vim.api.nvim_buf_line_count(buf), top = vim.fn.line("w0", win), height = vim.api.nvim_win_get_height(win),
    scroll = function(top)
      vim.w[win].term_user_scrolled = true -- the user is reading history (autocmds.lua)
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview({ topline = top, lnum = top })
      end)
    end,
  }
end

local function close(win)
  local bar = bars[win]
  if bar and vim.api.nvim_win_is_valid(bar.win) then
    pcall(vim.api.nvim_win_close, bar.win, true)
  end
  bars[win] = nil
end

local function draw(win, m)
  local height = vim.api.nvim_win_get_height(win)
  local width = vim.api.nvim_win_get_width(win)
  if m.total <= m.height or height < 2 or width < 3 then
    close(win) -- everything fits: no bar, like VS Code
    return
  end
  local size = math.max(1, math.floor(height * m.height / m.total + 0.5))
  local pos = math.min(height - size, math.floor((m.top - 1) * height / m.total + 0.5))

  local bar = bars[win]
  local key = table.concat({ height, width, size, pos }, ":")
  if bar and vim.api.nvim_win_is_valid(bar.win) and bar.key == key then
    return -- nothing moved: redrawing anyway made the panel under it flicker
  end
  if not bar or not vim.api.nvim_win_is_valid(bar.win) then
    local bbuf = vim.api.nvim_create_buf(false, true)
    vim.bo[bbuf].bufhidden = "wipe"
    local bwin = vim.api.nvim_open_win(bbuf, false, {
      relative = "win", win = win, row = 0, col = width - 1, width = 1, height = height,
      focusable = false, style = "minimal", zindex = 60, noautocmd = true,
    })
    vim.wo[bwin].winhighlight = "Normal:Normal,NormalFloat:Normal"
    vim.wo[bwin].winblend = 0
    bar = { win = bwin, buf = bbuf }
    bars[win] = bar
  else
    vim.api.nvim_win_set_config(bar.win, { relative = "win", win = win, row = 0, col = width - 1, width = 1, height = height })
  end
  local lines = {}
  for i = 1, height do
    lines[i] = " "
  end
  vim.api.nvim_buf_set_lines(bar.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bar.buf, ns, 0, -1)
  for row = pos, pos + size - 1 do
    vim.api.nvim_buf_set_extmark(bar.buf, ns, row, 0, { end_col = 1, hl_group = "ScrollbarThumb" })
  end
  bar.key = key
end

function M.refresh()
  local seen = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, m = pcall(metrics, win)
    if ok and m then
      seen[win] = true
      pcall(draw, win, m)
    end
  end
  for win in pairs(bars) do
    if not seen[win] then
      close(win)
    end
  end
end

local refresh = vim.schedule_wrap(M.refresh)
vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "BufWinEnter", "WinClosed", "TermOpen", "VimResized" }, {
  group = vim.api.nvim_create_augroup("vscode_scrollbar", { clear = true }),
  callback = function() refresh() end,
})
-- terminals grow with new output (Claude writing) without scrolling events
local timer = vim.uv.new_timer()
if timer then
  timer:start(500, 500, refresh)
end

-- Mouse on a bar: the panel whose bar is under the mouse, and the row on the bar
local function hit(pos)
  for win, bar in pairs(bars) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_is_valid(bar.win) then
      local row, col = unpack(vim.api.nvim_win_get_position(bar.win))
      local height = vim.api.nvim_win_get_height(bar.win)
      if pos.screencol == col + 1 and pos.screenrow > row and pos.screenrow <= row + height then
        return win, pos.screenrow - row - 1, height
      end
    end
  end
end

-- The thumb's middle goes where the mouse is, like dragging VS Code's slider
local function scroll_to(win, row, height)
  local m = metrics(win)
  if not m then
    return
  end
  local top = math.floor((row + 0.5) / height * m.total - m.height / 2) + 1
  top = math.max(1, math.min(top, m.total - m.height + 1))
  m.scroll(top)
  M.refresh() -- now, not scheduled: the drag loop below waits for the mouse
end

-- Holding the mouse on a bar: follow it until the button is released. The panel
-- below never sees these clicks, so nothing gets selected in the explorer.
local drag_keys = { [vim.keycode("<LeftDrag>")] = true, [vim.keycode("<LeftMouse>")] = true }
local release = vim.keycode("<LeftRelease>")
local function drag(win, row, height)
  scroll_to(win, row, height)
  vim.cmd.redraw()
  while true do
    local ok, key = pcall(vim.fn.getcharstr)
    if not ok or key == release then
      return
    end
    if not drag_keys[key] then
      vim.api.nvim_feedkeys(key, "t", false) -- any other key ends the drag and still counts
      return
    end
    local bar = bars[win]
    if not (bar and vim.api.nvim_win_is_valid(bar.win)) then
      return
    end
    local top = vim.api.nvim_win_get_position(bar.win)[1]
    scroll_to(win, math.max(0, math.min(vim.fn.getmousepos().screenrow - top - 1, height - 1)), height)
    vim.cmd.redraw()
  end
end

-- Panels that act on one click (the Git panel) register here: fn(mousepos) returns
-- true when it took the click
M.on_click = {}

local leftmouse = vim.keycode("<LeftMouse>")
for _, mode in ipairs({ "n", "v", "i", "t" }) do
  -- keep what a click did before: the terminal handling in autocmds.lua, or
  -- satellite's own bar in code windows (it only maps the key when it is free)
  local prev = vim.fn.maparg("<LeftMouse>", mode, false, true)
  local function fallback()
    if prev.callback then
      local keys = prev.callback()
      if prev.expr == 1 and type(keys) == "string" and keys ~= "" then
        vim.api.nvim_feedkeys(keys, prev.noremap == 1 and "n" or "m", false)
      end
    elseif mode ~= "t" and package.loaded["satellite"] then
      require("satellite.mouse").handle_leftmouse()
    else
      vim.api.nvim_feedkeys(leftmouse, "ni", false)
    end
  end
  vim.keymap.set(mode, "<LeftMouse>", function()
    if vim.fn.pumvisible() == 1 then
      -- a menu is open (right-click menu, completion): the click picks from it
      return vim.api.nvim_feedkeys(leftmouse, "ni", false)
    end
    local pos = vim.fn.getmousepos()
    local win, row, height = hit(pos)
    if not win and mode == "v" and vim.fn.mode():find("^[vVsS\22\19]") then
      -- a click drops the selection first, like VS Code, then lands as a normal click
      -- (a file or terminal it lands in is ready to type)
      vim.cmd('exe "normal! \\<Esc>"')
      vim.api.nvim_feedkeys(leftmouse, "mi", false)
      return vim.defer_fn(function()
        local b = vim.api.nvim_get_current_buf()
        local typable = vim.bo[b].buftype == "terminal"
          or (vim.bo[b].buftype == "" and vim.bo[b].modifiable and vim.api.nvim_buf_get_name(b) ~= "")
        if typable and vim.fn.mode() == "n" and vim.api.nvim_win_get_config(0).relative == "" then
          vim.cmd.startinsert()
        end
      end, 120)
    end
    if not win then
      for _, handler in ipairs(M.on_click) do
        if handler(pos) then
          return
        end
      end
      return fallback()
    end
    if vim.fn.mode() == "t" then
      -- a terminal only scrolls back outside typing mode, which ends after this
      vim.cmd.stopinsert()
      vim.schedule(function() drag(win, row, height) end)
      return
    end
    drag(win, row, height)
  end, { desc = prev.desc or "Click (scrollbar aware)" })
end

-- Right click: panels with their own menu (explorer, Git panel) register here like
-- on_click, from any window; elsewhere Neovim's own menu (Cut / Copy / Paste...)
M.on_right_click = {}
local rightmouse = vim.keycode("<RightMouse>")
for _, mode in ipairs({ "n", "v", "i", "t" }) do
  vim.keymap.set(mode, "<RightMouse>", function()
    if vim.fn.pumvisible() == 1 then
      return vim.api.nvim_feedkeys(rightmouse, "ni", false)
    end
    local pos = vim.fn.getmousepos()
    for _, handler in ipairs(M.on_right_click) do
      if handler(pos) then
        return
      end
    end
    vim.api.nvim_feedkeys(rightmouse, "ni", false)
  end, { desc = "Right click (panel menus)" })
end

return M
