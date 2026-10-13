-- Markdown preview like VS Code: a read-only rendered view of the file, and back to
-- editing. Three ways in, so it never depends on what a terminal lets through:
-- the Preview / Edit button at the top right of every markdown file (click it),
-- Ctrl+Shift+V or Ctrl+K V (Cmd+Shift+V on a Mac), and :MarkdownPreview.
local M = {}

local function install_parsers_then(buf, missing)
  if vim.g.md_parsers_tried then
    vim.notify("Markdown preview: could not install the markdown parsers (" .. table.concat(missing, ", ")
      .. "). Run :checkhealth nvim-treesitter", vim.log.levels.ERROR)
    return
  end
  vim.g.md_parsers_tried = true
  vim.notify("Installing the markdown preview (first time)...")
  require("nvim-treesitter").install(missing):await(function()
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
        pcall(vim.treesitter.start, buf, "markdown")
        M.toggle()
      end
    end)
  end)
end

-- The button shown at the top right of markdown files
local function winbar(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local label = vim.b[buf].md_preview and " 󰷈 Edit " or " 󰈈 Preview "
  vim.wo[win].winbar = "%=%#SnacksPickerSpecial#%@v:lua.MarkdownPreviewClick@" .. label .. "%X%*"
end

function M.toggle()
  if vim.bo.filetype ~= "markdown" then
    return false
  end
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local on = not vim.b[buf].md_preview
  -- the preview draws from the markdown parsers (Neovim ships them; install if gone)
  local missing = vim.tbl_filter(function(lang)
    return not pcall(vim.treesitter.language.add, lang)
  end, { "markdown", "markdown_inline" })
  if on and #missing > 0 then
    install_parsers_then(buf, missing)
    return true
  end
  local ok, err = pcall(function() require("render-markdown").set_buf(on) end)
  if not ok then
    vim.notify("Markdown preview failed: " .. tostring(err), vim.log.levels.ERROR)
    return true
  end
  vim.b[buf].md_preview = on
  vim.bo[buf].modifiable = not on
  -- a reading view: no line numbers or signs, like VS Code's preview
  if on then
    vim.w[win].md_numbers = { vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].signcolumn }
    vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].signcolumn = false, false, "no"
    vim.cmd.stopinsert()
  else
    local saved = vim.w[win].md_numbers
    if saved then
      vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].signcolumn = saved[1], saved[2], saved[3]
    end
    vim.cmd.startinsert()
  end
  winbar(win)
  return true
end

-- Click on the button: the click lands in that window, then toggles it
function _G.MarkdownPreviewClick()
  local pos = vim.fn.getmousepos()
  if pos.winid ~= 0 then
    vim.api.nvim_set_current_win(pos.winid)
  end
  M.toggle()
end

vim.api.nvim_create_user_command("MarkdownPreview", function() M.toggle() end, { desc = "Markdown preview / edit" })

-- Every window showing a markdown file gets the button; other windows lose it
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
  group = vim.api.nvim_create_augroup("vscode_markdown_button", { clear = true }),
  callback = function()
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return
    end
    if vim.bo.filetype == "markdown" and vim.bo.buftype == "" then
      winbar(win)
    elseif vim.wo[win].winbar:find("MarkdownPreviewClick", 1, true) then
      vim.wo[win].winbar = ""
    end
  end,
})
-- a markdown file opened with nvim is already on screen when this loads
for _, win in ipairs(vim.api.nvim_list_wins()) do
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype == "markdown" and vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
    winbar(win)
  end
end

return M
