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

local IMAGES = { "png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "avif", "tiff" }
-- Files nvim cannot show at all: they always open in the app the system uses for them
-- (video player, PDF reader, Excel, Word...), wherever they are opened from
local EXTERNAL = {
  "mp4", "mov", "mkv", "avi", "webm", "m4v", "wmv", "flv",
  "mp3", "wav", "flac", "ogg", "m4a", "aac", "wma",
  "pdf", "doc", "docx", "xls", "xlsx", "xlsm", "ppt", "pptx", "odt", "ods", "odp", "rtf",
  "zip", "7z", "rar", "gz", "tgz", "bz2", "xz", "iso", "dmg", "exe", "msi",
  "psd", "ai", "sketch", "fig", "blend", "fbx", "obj", "glb", "gltf", "uasset", "umap",
}

local M = {}

-- True when the file goes to a system app: nvim shows code, text, and images where
-- the terminal can draw them, and nothing else
function M.is_external(path)
  local ext = (path:match("%.([%w]+)$") or ""):lower()
  return vim.tbl_contains(EXTERNAL, ext) or (vim.tbl_contains(IMAGES, ext) and not can_show())
end

-- Open a file nvim does not show in the system app, saying so
function M.open_external(path)
  open_external(path)
  local ext = (path:match("%.([%w]+)$") or ""):lower()
  local app = vim.tbl_contains(IMAGES, ext) and "image viewer" or "default app"
  vim.notify("Opened " .. vim.fn.fnamemodify(path, ":t") .. " in the system " .. app)
end

local function patterns(list)
  return vim.tbl_map(function(e) return "*." .. e end, list)
end

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("vscode_images", { clear = true }),
  pattern = vim.list_extend(patterns(IMAGES), patterns(EXTERNAL)),
  callback = function(ev)
    local path = vim.fn.fnamemodify(ev.match, ":p")
    if not M.is_external(path) then
      return
    end
    M.open_external(path)
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

return M
