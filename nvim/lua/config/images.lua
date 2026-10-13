-- Image files. Where the terminal speaks the kitty graphics protocol (WezTerm, kitty,
-- ghostty) Snacks image shows them; anywhere else they open in the system viewer
-- instead of as binary text.
local function can_show()
  return Snacks and Snacks.image and Snacks.image.supports_terminal() or false
end

local function open_external(path)
  if vim.ui.open then
    -- vim.ui.open returns nil plus a message when it cannot launch
    local ok, handle = pcall(vim.ui.open, path)
    if ok and handle then
      return
    end
  end
  local cmd
  if vim.fn.has("win32") == 1 then
    cmd = { "cmd", "/c", "start", "", path }
  elseif vim.fn.has("mac") == 1 then
    cmd = { "open", path }
  else
    cmd = { "xdg-open", path }
  end
  pcall(vim.system, cmd, { detach = true })
end

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("vscode_images", { clear = true }),
  pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.ico", "*.avif", "*.tiff" },
  callback = function(ev)
    if can_show() then
      return
    end
    local path = vim.fn.fnamemodify(ev.match, ":p")
    open_external(path)
    vim.notify("Opened " .. vim.fn.fnamemodify(path, ":t") .. " in the system image viewer")
    -- no binary text: go back to the previous buffer (or the start screen)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= ev.buf and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
        vim.api.nvim_win_set_buf(0, alt)
      elseif vim.api.nvim_get_current_buf() == ev.buf then
        vim.cmd("enew")
        pcall(Snacks.dashboard)
      end
      pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
    end)
  end,
})
