-- Closing a tab like VS Code (Ctrl+W, the X on the tab, middle click):
-- * a side-by-side diff (:diffsplit, a proposed change) closes as one: both sides go
--   and the editor is back to a single panel
-- * a file open in a side panel (split) closes that panel, like closing the last
--   tab of a VS Code editor group; in the only panel the next tab shows instead
-- * unsaved changes ask first: Save / Don't Save / Cancel
-- Right click on a tab: Close, Close Others, Close to the Right, Close All, Copy Path,
-- Reveal in File Explorer.
local M = {}

local SIDE = { snacks_picker_list = true, snacks_picker_input = true, snacks_layout_box = true, vscode_scm = true,
  snacks_terminal = true, snacks_dashboard = true }

-- the panels of the code area (not the explorer, Git panel, terminals or floats)
local function editor_wins()
  local wins = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_win_get_config(w).relative == "" and vim.bo[b].buftype ~= "terminal"
      and not SIDE[vim.bo[b].filetype] then
      wins[#wins + 1] = w
    end
  end
  return wins
end
M.editor_wins = editor_wins

-- the other side of a diff opened from the Git panel (window variable set there)
local function peer(win)
  local p = vim.w[win].vscode_diff_peer
  return p and vim.api.nvim_win_is_valid(p) and p or nil
end

-- true when it is fine to close (saved, or the user chose)
local function confirm_save(buf)
  if not vim.bo[buf].modified or vim.bo[buf].buftype ~= "" then
    return true
  end
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
  local choice = vim.fn.confirm(("Save the changes to %s?"):format(name ~= "" and name or "Untitled"),
    "&Save\n&Don't Save\n&Cancel", 1)
  if choice == 1 then
    vim.api.nvim_buf_call(buf, function()
      if vim.api.nvim_buf_get_name(buf) == "" then
        vim.cmd("write") -- unnamed: Ctrl+S asks for the name; :write explains instead
      else
        vim.cmd("silent write")
      end
    end)
    return not vim.bo[buf].modified
  end
  return choice == 2
end

-- the diff around `win` (if any) ends: the old side closes, the file stays
local function end_diff(win)
  local p = peer(win)
  if p then
    vim.w[win].vscode_diff_peer, vim.w[p].vscode_diff_peer = nil, nil
    vim.w[win].vscode_diff_close_file, vim.w[p].vscode_diff_close_file = nil, nil
    local pbuf = vim.api.nvim_win_get_buf(p)
    if vim.bo[pbuf].buftype ~= "" then -- the read-only old version
      pcall(vim.api.nvim_win_close, p, true)
    else
      vim.api.nvim_win_call(p, function() vim.cmd("diffoff") end)
    end
  end
  if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
    vim.api.nvim_win_call(win, function() vim.cmd("diffoff") end)
  end
end
M.end_diff = end_diff

function M.close(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  -- the same file in two panels (Ctrl+\): only this panel closes, the file stays open
  local cur = vim.api.nvim_get_current_win()
  local showing = vim.tbl_filter(function(w) return vim.api.nvim_win_get_buf(w) == buf end, editor_wins())
  if #showing > 1 and vim.api.nvim_win_get_buf(cur) == buf and not peer(cur) then
    return pcall(vim.api.nvim_win_close, cur, false)
  end
  -- the old side of a diff whose file was opened just for it: the whole diff goes,
  -- like VS Code's diff tab, instead of leaving that file open
  local old_side = vim.api.nvim_win_get_buf(cur) == buf and cur or vim.fn.win_findbuf(buf)[1]
  if old_side and vim.w[old_side].vscode_diff_close_file and peer(old_side) then
    local file = vim.api.nvim_win_get_buf(peer(old_side))
    vim.w[old_side].vscode_diff_close_file = nil
    return M.close(file)
  end
  if not confirm_save(buf) then
    return
  end
  local wins = vim.tbl_filter(function(w) return vim.api.nvim_win_get_buf(w) == buf end, editor_wins())
  -- diffs close as one tab
  for _, w in ipairs(wins) do
    end_diff(w)
  end
  wins = vim.tbl_filter(function(w) return vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == buf end, editor_wins())
  -- extra panels showing it close (a split shows one file, like a VS Code group);
  -- one panel always stays for the code area
  local all = #editor_wins()
  for _, w in ipairs(wins) do
    if all > 1 then
      pcall(vim.api.nvim_win_close, w, true)
      all = all - 1
    end
  end
  if vim.api.nvim_buf_is_valid(buf) then
    if vim.bo[buf].buflisted then
      Snacks.bufdelete({ buf = buf, force = true }) -- shows the next tab where it still was
    else
      -- a read-only view (old version of a diff, image): its panel closes, or the
      -- last panel shows the previous file
      for _, w in ipairs(vim.fn.win_findbuf(buf)) do
        if #editor_wins() > 1 then
          pcall(vim.api.nvim_win_close, w, true)
        else
          vim.api.nvim_win_call(w, function() pcall(vim.cmd, "bprevious") end)
        end
      end
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- Any diff left with one side (Claude's proposed change closed, a side closed with
-- :q or the mouse...) goes back to a normal file view instead of staying grey
-- and folded
vim.api.nvim_create_autocmd({ "WinClosed", "BufWinLeave" }, {
  group = vim.api.nvim_create_augroup("vscode_lone_diff", { clear = true }),
  callback = function()
    vim.schedule(function()
      local diffs = vim.tbl_filter(function(w)
        return vim.api.nvim_win_is_valid(w) and vim.wo[w].diff
      end, vim.api.nvim_tabpage_list_wins(0))
      if #diffs == 1 then
        vim.w[diffs[1]].vscode_diff_peer, vim.w[diffs[1]].vscode_diff_close_file = nil, nil
        vim.api.nvim_win_call(diffs[1], function() vim.cmd("diffoff") end)
      end
    end)
  end,
})

-- right click on a tab
local function listed()
  return vim.tbl_filter(function(b) return vim.bo[b].buflisted end, vim.api.nvim_list_bufs())
end
function M.context(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local function close_many(pick)
    for _, b in ipairs(listed()) do
      if pick(b) and vim.api.nvim_buf_is_valid(b) then
        M.close(b)
      end
    end
  end
  local items = {
    { "Close", function() M.close(buf) end },
    { "Close Others", function() close_many(function(b) return b ~= buf end) end },
    { "Close to the Right", function()
      local seen = false
      local ok, elements = pcall(function() return require("bufferline").get_elements().elements end)
      for _, e in ipairs(ok and elements or {}) do
        if seen then
          M.close(e.id)
        end
        seen = seen or e.id == buf
      end
    end },
    { "Close Saved", function() close_many(function(b) return not vim.bo[b].modified end) end },
    { "Close All", function() close_many(function() return true end) end },
  }
  if path ~= "" then
    vim.list_extend(items, {
      "-",
      { "Copy Path", function() vim.fn.setreg("+", vim.fs.normalize(path)) end },
      { "Copy Relative Path", function() vim.fn.setreg("+", vim.fn.fnamemodify(path, ":.")) end },
      { vim.fn.has("mac") == 1 and "Reveal in Finder" or "Reveal in File Explorer", function()
        if vim.fn.has("win32") == 1 then
          vim.system({ "explorer.exe", "/select," .. path:gsub("/", "\\") }, { detach = true })
        elseif vim.fn.has("mac") == 1 then
          vim.system({ "open", "-R", path }, { detach = true })
        else
          vim.system({ "xdg-open", vim.fs.dirname(path) }, { detach = true })
        end
      end },
      { "Reveal in Explorer View", function() Snacks.explorer.reveal({ file = path }) end },
    })
  end
  require("config.menu").open(items)
end

return M
