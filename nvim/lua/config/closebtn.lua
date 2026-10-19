-- Every panel that opens (replace in project, help, messages, quickfix, terminals,
-- plugin panels) gets a close button (󰅖) at the top right, like VS Code. Files close
-- from their tab. The sidebar sections (explorer, Git) are not closed but folded,
-- like VS Code's: they have their own header.
local M = {}

local OWN_HEADER = { snacks_picker_list = true, snacks_picker_input = true, snacks_layout_box = true,
  vscode_scm = true, snacks_dashboard = true }

function _G.VSCodeCloseButton(win)
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    if #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end,
        vim.api.nvim_tabpage_list_wins(0)) > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    else
      vim.api.nvim_win_call(win, function() vim.cmd("enew") end) -- the last panel stays, empty
    end
  end)
end

local function is_panel(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local bo = vim.bo[buf]
  return vim.api.nvim_win_get_config(win).relative == "" and bo.buftype ~= ""
    and not OWN_HEADER[bo.filetype] and not vim.b[buf].image_view
end

function M.decorate(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local bar = vim.wo[win].winbar
  local button = ("%%%d@v:lua.VSCodeCloseButton@%%#VSCodeCloseButton# 󰅖 %%*%%X"):format(win)
  local has = bar:find(button, 1, true)
  if is_panel(win) then
    if not has then
      vim.wo[win].winbar = (bar ~= "" and bar or "%=") .. button
    end
  elseif has then
    -- the panel now shows a file: its tab closes it
    local rest = bar:sub(1, has - 1) .. bar:sub(has + #button)
    vim.wo[win].winbar = rest == "%=" and "" or rest
  end
end

local function colors()
  vim.api.nvim_set_hl(0, "VSCodeCloseButton", { link = "Special", default = true })
end
colors()

local group = vim.api.nvim_create_augroup("vscode_close_button", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = colors })
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "TermOpen", "WinNew" }, {
  group = group,
  callback = function()
    vim.schedule(function()
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        M.decorate(w)
      end
    end)
  end,
})

return M
