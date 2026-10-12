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

-- A click on another panel moves there directly; clicks inside the terminal reach the app
vim.keymap.set("t", "<LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  if pos.winid ~= 0 and pos.winid ~= vim.api.nvim_get_current_win() then
    -- Windows cannot change inside an expr mapping, so switch right after it
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(pos.winid) then
        vim.api.nvim_set_current_win(pos.winid)
        if pos.line > 0 then
          pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, math.max(pos.column - 1, 0) })
        end
      end
    end)
    return ""
  end
  return "<LeftMouse>"
end, { expr = true, desc = "Click another panel from a terminal" })

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
