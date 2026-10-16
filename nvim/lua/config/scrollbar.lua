-- Scrollbar for the panels satellite.nvim leaves out: terminals (Claude, shells) and
-- the file explorer list. A one-column strip on the right edge of the panel; the
-- lighter part is the slice on screen. It follows scrolling, resizing and new output.
local M = {}

local bars = {} -- target window -> { win = bar window, buf = bar buffer }
local ns = vim.api.nvim_create_namespace("vscode_scrollbar")

local function wanted(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.b[buf].image_view then
    return false
  end
  return vim.bo[buf].buftype == "terminal" or vim.bo[buf].filetype == "snacks_picker_list"
end

local function close(win)
  local bar = bars[win]
  if bar and vim.api.nvim_win_is_valid(bar.win) then
    pcall(vim.api.nvim_win_close, bar.win, true)
  end
  bars[win] = nil
end

local function colors()
  -- one soft gray for every bar, like VS Code's scrollbar slider (satellite's bar in
  -- code windows included)
  vim.api.nvim_set_hl(0, "ScrollbarThumb", { bg = "#4a4e52" })
  vim.api.nvim_set_hl(0, "SatelliteBar", { link = "ScrollbarThumb" })
end
colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

local function draw(win)
  local height = vim.api.nvim_win_get_height(win)
  local width = vim.api.nvim_win_get_width(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local total = vim.api.nvim_buf_line_count(buf)
  if total <= height or height < 2 or width < 3 then
    close(win) -- everything fits: no bar, like VS Code
    return
  end
  local top = vim.fn.line("w0", win)
  local size = math.max(1, math.floor(height * height / total + 0.5))
  local pos = math.min(height - size, math.floor((top - 1) * height / total + 0.5))

  local bar = bars[win]
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
end

function M.refresh()
  local seen = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if wanted(win) then
      seen[win] = true
      pcall(draw, win)
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

return M
