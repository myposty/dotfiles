-- Source control panel like VS Code: lives under the file explorer, plain text
-- (no terminal), refreshed in real time. Shows branch, staged changes, changes
-- and untracked files; stage, unstage, commit, push and pull from the keyboard.
local M = {}

local FT = "vscode_scm"
local ns = vim.api.nvim_create_namespace("vscode_scm")
local state = { buf = nil, win = nil, timer = nil, entries = {}, busy = false }

local HINT = " s stage/unstage · a all · c commit · p push · P pull · ↵ open · g lazygit · q close"

local function root()
  local out = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "rev-parse", "--show-toplevel" })
  return vim.v.shell_error == 0 and out[1] or nil
end

local function git(args, on_done)
  local cmd = { "git", "-C", root() or vim.fn.getcwd() }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(res)
    vim.schedule(function()
      on_done(res)
    end)
  end)
end

local function valid()
  return state.win and vim.api.nvim_win_is_valid(state.win) and state.buf and vim.api.nvim_buf_is_valid(state.buf)
end

-- Parse `git status --porcelain=v1 --branch` into display lines and entries
local function parse(out)
  local lines, entries, hls = {}, {}, {}
  local staged, changes = {}, {}
  local head = "no branch"
  for _, l in ipairs(vim.split(out, "\n", { trimempty = true })) do
    if l:sub(1, 2) == "##" then
      local h = l:sub(4)
      local branch = h:match("^No commits yet on (%S+)") or h:match("^([^%s%.]+)") or h
      local ahead, behind = h:match("ahead (%d+)"), h:match("behind (%d+)")
      head = branch .. ((ahead or behind) and ("  ↑" .. (ahead or 0) .. " ↓" .. (behind or 0)) or "")
    else
      local x, y, path = l:sub(1, 1), l:sub(2, 2), l:sub(4)
      path = path:gsub("^.* %-> ", "") -- renames: show the new name
      if x == "?" then
        table.insert(changes, { code = "U", path = path, staged = false })
      else
        if x ~= " " then
          table.insert(staged, { code = x, path = path, staged = true })
        end
        if y ~= " " then
          table.insert(changes, { code = y, path = path, staged = false })
        end
      end
    end
  end

  local function add(text, hl, entry)
    lines[#lines + 1] = text
    if hl then
      hls[#hls + 1] = { #lines - 1, hl }
    end
    entries[#lines] = entry
  end

  add(" " .. head, "Title")
  add("")
  add((" STAGED (%d)"):format(#staged), "Special")
  for _, e in ipairs(staged) do
    add(("   %s  %s"):format(e.code, e.path), "DiffAdd", e)
  end
  add((" CHANGES (%d)"):format(#changes), "Special")
  for _, e in ipairs(changes) do
    add(("   %s  %s"):format(e.code, e.path), e.code == "U" and "Comment" or "DiffChange", e)
  end
  if #staged == 0 and #changes == 0 then
    add("   clean, nothing to commit", "Comment")
  end
  add("")
  add(HINT, "Comment")
  return lines, entries, hls
end

function M.refresh()
  if not valid() or state.busy then
    return
  end
  if not root() then
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { " Not a git repository", "", HINT })
    vim.bo[state.buf].modifiable = false
    return
  end
  state.busy = true
  git({ "status", "--porcelain=v1", "--branch" }, function(res)
    state.busy = false
    if not valid() then
      return
    end
    local lines, entries, hls = parse(res.stdout or "")
    state.entries = entries
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
    for _, h in ipairs(hls) do
      vim.api.nvim_buf_set_extmark(state.buf, ns, h[1], 0, { hl_group = h[2], end_col = #lines[h[1] + 1], strict = false })
    end
    pcall(vim.api.nvim_win_set_cursor, state.win, { math.min(cursor[1], #lines), 0 })
  end)
end

local function current_entry()
  return state.entries[vim.api.nvim_win_get_cursor(0)[1]]
end

local function report(what)
  return function(res)
    local msg = vim.trim((res.stdout or "") .. "\n" .. (res.stderr or ""))
    vim.notify(what .. (res.code == 0 and " done" or " failed") .. (msg ~= "" and ("\n" .. msg) or ""),
      res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR, { title = "Git" })
    M.refresh()
  end
end

local function toggle_stage()
  local e = current_entry()
  if not e then
    return
  end
  if e.staged then
    git({ "restore", "--staged", "--", e.path }, function() M.refresh() end)
  else
    git({ "add", "--", e.path }, function() M.refresh() end)
  end
end

local function commit()
  vim.ui.input({ prompt = "Commit message: " }, function(msg)
    if msg and vim.trim(msg) ~= "" then
      git({ "commit", "-m", msg }, report("Commit"))
    end
  end)
end

local function open_file()
  local e = current_entry()
  if not e then
    return
  end
  local path = vim.fs.joinpath(root(), e.path)
  -- open in the main editor area (the window right of the side panels)
  vim.cmd("wincmd l")
  if vim.api.nvim_get_current_win() == state.win then
    vim.cmd("vsplit")
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function map_keys(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "s", toggle_stage, o)
  vim.keymap.set("n", "<space>", toggle_stage, o)
  vim.keymap.set("n", "a", function() git({ "add", "-A" }, function() M.refresh() end) end, o)
  vim.keymap.set("n", "c", commit, o)
  vim.keymap.set("n", "p", function() vim.notify("Pushing...", vim.log.levels.INFO, { title = "Git" }) git({ "push" }, report("Push")) end, o)
  vim.keymap.set("n", "P", function() vim.notify("Pulling...", vim.log.levels.INFO, { title = "Git" }) git({ "pull" }, report("Pull")) end, o)
  vim.keymap.set("n", "<cr>", open_file, o)
  vim.keymap.set("n", "<2-LeftMouse>", open_file, o)
  vim.keymap.set("n", "r", M.refresh, o)
  vim.keymap.set("n", "g", function() Snacks.lazygit() end, o)
  vim.keymap.set("n", "q", M.close, o)
end

local function explorer_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
    if vim.api.nvim_win_get_config(w).relative == "" and (ft == "snacks_layout_box" or ft == "snacks_picker_list") then
      return w
    end
  end
end

-- opts.focus = false keeps the cursor where it is (used when it opens with the explorer)
function M.open(opts)
  opts = opts or {}
  local focus = opts.focus ~= false
  if valid() then
    if focus then
      vim.api.nvim_set_current_win(state.win)
    end
    return
  end
  local anchor = explorer_win()
  if not anchor then
    Snacks.explorer.open()
    return vim.defer_fn(function() M.open(opts) end, 150)
  end
  local previous = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].filetype = FT
  vim.bo[state.buf].bufhidden = "wipe"
  local height = math.max(8, math.floor(vim.api.nvim_win_get_height(anchor) * 0.4))
  state.win = vim.api.nvim_open_win(state.buf, true, { split = "below", win = anchor, height = height })
  for opt, val in pairs({ number = false, relativenumber = false, signcolumn = "no", wrap = false,
    cursorline = true, winfixheight = true, winfixwidth = true, statuscolumn = "", foldcolumn = "0" }) do
    vim.wo[state.win][opt] = val
  end
  vim.wo[state.win].winbar = " SOURCE CONTROL"
  map_keys(state.buf)
  M.refresh()
  -- the explorer re-focuses itself while its layout settles; set the focus after it
  vim.defer_fn(function()
    if focus and valid() then
      vim.api.nvim_set_current_win(state.win)
      vim.cmd.stopinsert()
    elseif not focus and vim.api.nvim_win_is_valid(previous) then
      vim.api.nvim_set_current_win(previous)
    end
  end, 150)

  -- real time: poll every 2 s while open, plus on save / focus / terminal close / folder change
  state.timer = vim.uv.new_timer()
  state.timer:start(2000, 2000, vim.schedule_wrap(M.refresh))
  local group = vim.api.nvim_create_augroup("vscode_scm", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "TermClose", "DirChanged" }, {
    group = group,
    callback = function() vim.defer_fn(M.refresh, 100) end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = state.buf,
    callback = function()
      if state.timer then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
      end
      state.win, state.buf = nil, nil
      pcall(vim.api.nvim_del_augroup_by_name, "vscode_scm")
    end,
  })
end

function M.close()
  if valid() then
    vim.api.nvim_win_close(state.win, true)
  end
end

-- Like VS Code's sidebar: the panel shows up under the explorer whenever the
-- explorer opens inside a git repository, and closes together with it
local auto = vim.api.nvim_create_augroup("vscode_scm_auto", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = auto,
  pattern = "snacks_picker_list",
  callback = function()
    vim.defer_fn(function()
      if not valid() and explorer_win() and root() then
        M.open({ focus = false })
      end
    end, 200)
  end,
})
vim.api.nvim_create_autocmd("WinClosed", {
  group = auto,
  callback = function()
    vim.defer_fn(function()
      if valid() and not explorer_win() then
        M.close()
      end
    end, 50)
  end,
})

function M.toggle()
  if valid() then
    if vim.api.nvim_get_current_win() == state.win then
      M.close()
    else
      vim.api.nvim_set_current_win(state.win)
    end
  else
    M.open()
  end
end

return M
