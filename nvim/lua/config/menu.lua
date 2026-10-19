-- Context menu (right click), like VS Code's: a small box at the mouse with the
-- actions of what was clicked. Click an item, or move with the arrows / j k and press
-- Enter; Esc, q or a click outside closes it. Neovim's own popup menu could not be
-- used: it closes by itself whenever a panel refreshes (explorer, Git panel).
local M = {}

local state = {} -- { win, buf, items, prev }
local ns = vim.api.nvim_create_namespace("vscode_menu")

local function colors()
  vim.api.nvim_set_hl(0, "VSCodeMenu", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "VSCodeMenuSel", { fg = "#ffffff", bg = "#0078d4", default = true }) -- VS Code blue
  vim.api.nvim_set_hl(0, "VSCodeMenuSep", { link = "FloatBorder", default = true })
end
colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  if state.prev and vim.api.nvim_win_is_valid(state.prev) then
    pcall(vim.api.nvim_set_current_win, state.prev)
  end
  state = {}
end

function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function run(i)
  local item = state.items and state.items[i]
  if not item or not item.run then
    return
  end
  M.close()
  vim.schedule(item.run)
end

local function step(dir)
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  for _ = 1, #state.items do
    row = (row - 1 + dir) % #state.items + 1
    if state.items[row].run then
      break
    end
  end
  vim.api.nvim_win_set_cursor(state.win, { row, 0 })
end

-- items: { { label, fn }, "-" (separator), ... }
function M.open(items)
  M.close()
  local list, width = {}, 0
  for _, it in ipairs(items) do
    if it == "-" then
      list[#list + 1] = { sep = true }
    else
      list[#list + 1] = { label = it[1], run = it[2] }
      width = math.max(width, vim.fn.strdisplaywidth(it[1]))
    end
  end
  width = width + 4
  local lines = {}
  for i, it in ipairs(list) do
    lines[i] = it.sep and string.rep("─", width) or ("  " .. it.label)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "vscode_menu"
  for i, it in ipairs(list) do
    if it.sep then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { line_hl_group = "VSCodeMenuSep" })
    end
  end
  -- at the mouse, moved up / left when it would leave the screen
  local pos = vim.fn.getmousepos()
  local row = math.min(pos.screenrow, vim.o.lines - #lines - 3)
  local col = math.min(pos.screencol, vim.o.columns - width - 2)
  state.prev = vim.api.nvim_get_current_win()
  state.items = list
  state.buf = buf
  state.win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", row = math.max(0, row), col = math.max(0, col), width = width, height = #lines,
    border = "rounded", style = "minimal", zindex = 250,
  })
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].winhighlight = "Normal:VSCodeMenu,CursorLine:VSCodeMenuSel"
  vim.cmd.stopinsert()
  vim.api.nvim_win_set_cursor(state.win, { #list, 0 })
  step(1) -- wraps around to the first item
  local o = { buffer = buf, nowait = true, silent = true }
  for _, k in ipairs({ "j", "<Down>", "<Tab>" }) do
    vim.keymap.set("n", k, function() step(1) end, o)
  end
  for _, k in ipairs({ "k", "<Up>", "<S-Tab>" }) do
    vim.keymap.set("n", k, function() step(-1) end, o)
  end
  vim.keymap.set("n", "<CR>", function() run(vim.api.nvim_win_get_cursor(0)[1]) end, o)
  for _, k in ipairs({ "<Esc>", "q" }) do
    vim.keymap.set("n", k, M.close, o)
  end
  -- leaving it (a click elsewhere) closes it
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if state.buf == buf then
          state.prev = nil -- the click already chose where to go
          M.close()
        end
      end)
    end,
  })
end

-- a click on an item runs it (first in the scrollbar's mouse handling)
table.insert(require("config.scrollbar").on_click, 1, function(pos)
  if not M.is_open() then
    return false
  end
  if pos.winid == state.win then
    if pos.line >= 1 then
      run(pos.line)
    end
    return true
  end
  state.prev = nil
  M.close() -- a click outside closes it and does what it normally does
  return false
end)

return M
