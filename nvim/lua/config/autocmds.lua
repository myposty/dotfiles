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

vim.keymap.set("t", "<LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  local divider, info = divider_at(pos)
  if divider then
    drag = divider
    return ""
  end
  if info and pos.winid == vim.api.nvim_get_current_win() then
    return ""
  end
  -- Windows cannot change inside an expr mapping, so switch right after it
  if info then
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
end, { expr = true, desc = "Click from a terminal" })

-- A click inside a terminal that is not in typing mode puts it back in typing mode
vim.keymap.set("n", "<LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  local info = pos.winid ~= 0 and vim.fn.getwininfo(pos.winid)[1] or nil
  local on_content = info and pos.wincol <= info.width and pos.winrow <= info.height
  if on_content and vim.bo[vim.api.nvim_win_get_buf(pos.winid)].buftype == "terminal" then
    vim.schedule(function()
      if vim.bo.buftype == "terminal" and vim.fn.mode() ~= "t" then
        vim.cmd.startinsert()
      end
    end)
  end
  return "<LeftMouse>"
end, { expr = true, desc = "Click" })

vim.keymap.set("t", "<LeftDrag>", function()
  if drag and vim.api.nvim_win_is_valid(drag.win) then
    local pos = vim.fn.getmousepos()
    local info = vim.fn.getwininfo(drag.win)[1]
    vim.schedule(function()
      if drag.kind == "vertical" then
        vim.api.nvim_win_set_width(drag.win, math.max(pos.screencol - info.wincol, 1))
      else
        vim.api.nvim_win_set_height(drag.win, math.max(pos.screenrow - info.winrow, 1))
      end
    end)
  end
  return ""
end, { expr = true, desc = "Resize panels from a terminal" })

vim.keymap.set("t", "<LeftRelease>", function()
  drag = nil
  return ""
end, { expr = true, desc = "Stop resizing" })

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
