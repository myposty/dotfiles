-- Files nvim cannot show as text. Images open inside the editor, like VS Code:
-- Snacks image draws them where the terminal speaks the kitty graphics protocol
-- (WezTerm, kitty, ghostty); in any other terminal (Windows Terminal, Terminal.app,
-- GNOME...) chafa draws them with colored blocks in a tab. Video, PDF, Office and
-- other files open in the app the system uses for them.
local M = {}

local IMAGES = { "png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "avif", "tiff" }
local EXTERNAL = {
  "mp4", "mov", "mkv", "avi", "webm", "m4v", "wmv", "flv",
  "mp3", "wav", "flac", "ogg", "m4a", "aac", "wma",
  "pdf", "doc", "docx", "xls", "xlsx", "xlsm", "ppt", "pptx", "odt", "ods", "odp", "rtf",
  "zip", "7z", "rar", "gz", "tgz", "bz2", "xz", "iso", "dmg", "exe", "msi",
  "psd", "ai", "sketch", "fig", "blend", "fbx", "obj", "glb", "gltf", "uasset", "umap",
}

local function ext_of(path)
  return (path:match("%.([%w]+)$") or ""):lower()
end

-- chafa on PATH, or where winget unpacked it (a terminal opened before the install
-- still has the old PATH)
local chafa
local function chafa_cmd()
  if chafa == nil then
    chafa = vim.fn.exepath("chafa")
    if chafa == "" and vim.fn.has("win32") == 1 then
      local found = vim.fn.glob(vim.env.LOCALAPPDATA .. "/Microsoft/WinGet/Packages/hpjansson.Chafa*/*/chafa.exe", true, true)
      chafa = found[1] or ""
    end
  end
  return chafa ~= "" and chafa or nil
end

local function snacks_can_show()
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

-- True when the file goes to a system app: nvim shows code, text and images (images
-- only go out when neither Snacks image nor chafa can draw them)
function M.is_external(path)
  local ext = ext_of(path)
  if vim.tbl_contains(IMAGES, ext) then
    return not snacks_can_show() and not chafa_cmd()
  end
  return vim.tbl_contains(EXTERNAL, ext)
end

function M.open_external(path)
  open_external(path)
  local image = vim.tbl_contains(IMAGES, ext_of(path))
  vim.notify("Opened " .. vim.fn.fnamemodify(path, ":t") .. " in the system "
    .. (image and "image viewer (install chafa to see images inside nvim)" or "default app"))
end

-- Draw an image with chafa in a fresh terminal buffer shown in `win`; returns the buffer
local function draw(win, path)
  local width = math.max(vim.api.nvim_win_get_width(win) - 1, 10)
  local height = math.max(vim.api.nvim_win_get_height(win) - 1, 5)
  -- Terminal.app (and others nvim runs with 256 colors) get a 256-color drawing
  local colors = vim.o.termguicolors and "full" or "256"
  local res = vim.system({ chafa_cmd(), "--size", width .. "x" .. height, "--format", "symbols", "--colors", colors,
    "--animate", "off", "--polite", "on", path }, { text = true }):wait(10000)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.b[buf].image_view = path
  vim.api.nvim_win_set_buf(win, buf)
  -- a terminal surface with no process behind it: it shows the colors, never exits
  local chan = vim.api.nvim_open_term(buf, {})
  if res.code == 0 then
    vim.api.nvim_chan_send(chan, ((res.stdout or ""):gsub("\r?\n", "\r\n")))
  else
    vim.api.nvim_chan_send(chan, "Could not draw " .. path .. "\r\n" .. (res.stderr or ""))
  end
  pcall(vim.api.nvim_buf_set_name, buf, vim.fn.fnamemodify(path, ":t") .. " (image)")
  vim.bo[buf].buflisted = true
  vim.keymap.set("n", "q", function() Snacks.bufdelete(buf) end, { buffer = buf, desc = "Close image" })
  return buf
end

-- An image tab: drawn now and redrawn to fit when the window changes size
local function view(win, path)
  local buf = draw(win, path)
  local group = vim.api.nvim_create_augroup("vscode_image_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = group,
    callback = function()
      for _, w in ipairs(vim.fn.win_findbuf(buf)) do
        local old = buf
        buf = draw(w, path)
        pcall(vim.api.nvim_buf_delete, old, { force = true })
        return
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, buffer = buf, callback = function()
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end })
end

local function patterns(list)
  return vim.tbl_map(function(e) return "*." .. e end, list)
end

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("vscode_images", { clear = true }),
  pattern = vim.list_extend(patterns(IMAGES), patterns(EXTERNAL)),
  callback = function(ev)
    local path = vim.fn.fnamemodify(ev.match, ":p")
    local image = vim.tbl_contains(IMAGES, ext_of(path))
    if image and snacks_can_show() then
      return -- Snacks image draws it in this buffer
    end
    local win = vim.api.nvim_get_current_win()
    vim.schedule(function()
      if image and chafa_cmd() and vim.api.nvim_win_is_valid(win) then
        view(win, path)
      else
        M.open_external(path)
        -- nothing to show in the editor: back to the previous buffer (or the start screen)
        local alt = vim.fn.bufnr("#")
        if alt > 0 and alt ~= ev.buf and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
          vim.api.nvim_win_set_buf(win, alt)
        elseif vim.api.nvim_get_current_buf() == ev.buf then
          vim.cmd("enew")
          pcall(Snacks.dashboard)
        end
      end
      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
      end
    end)
  end,
})

return M
