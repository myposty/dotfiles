-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

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
