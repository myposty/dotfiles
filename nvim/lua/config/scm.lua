-- Source control panel like VS Code's: lives under the file explorer, plain text
-- (no terminal), refreshed in real time.
--   * header buttons: commit, refresh, sync (pull + push), branches, lazygit
--   * the branch (click: switch or create a branch) and a Commit line
--   * STAGED CHANGES / CHANGES: double-click a file to see its changes (diff)
--   * GRAPH: recent commits of every branch with their branch names; double-click
--     one to see what it changed
--   * right click: the menu of the line (Open Changes, Stage, Discard...)
-- Keys inside: s stage/unstage, a stage all, u unstage all, x discard, c commit,
-- o open file, b branches, B new branch, p push, P pull, f fetch, S sync.
local M = {}

local FT = "vscode_scm"
local ns = vim.api.nvim_create_namespace("vscode_scm")
local state = { buf = nil, win = nil, timer = nil, entries = {}, busy = false, staged = 0, changes = 0 }

local HINT = " s stage · x discard · c commit · b branch · ? keys"
local KEYS = {
  "Source control keys",
  "",
  "double-click / Enter  see changes (file), switch branch, commit, see a commit",
  "right click    menu of the line",
  "s / Space      stage or unstage the file",
  "a / u          stage all / unstage all",
  "x              discard the changes of the file",
  "o              open the file",
  "c              commit (stages everything when nothing is staged)",
  "b / B          switch branch / new branch",
  "p / P / f / S  push / pull / fetch / sync (pull then push)",
  "r              refresh",
  "g              lazygit (merge, rebase, stash, history)",
  "q              close",
}

local root_cache = {}
local function root()
  local cwd = vim.fn.getcwd()
  if not root_cache[cwd] then -- only found roots are kept: a `git init` shows up later
    local out = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
    root_cache[cwd] = vim.v.shell_error == 0 and out[1] or nil
  end
  return root_cache[cwd]
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

-- VS Code's letter colors: modified yellow, added/untracked green, deleted red
local CODE_HL = { M = "ScmModified", A = "ScmAdded", U = "ScmAdded", R = "ScmAdded", C = "ScmAdded", D = "ScmDeleted" }
local function colors()
  vim.api.nvim_set_hl(0, "ScmModified", { fg = "#e2c08d", default = true })
  vim.api.nvim_set_hl(0, "ScmAdded", { fg = "#73c991", default = true })
  vim.api.nvim_set_hl(0, "ScmDeleted", { fg = "#c74e39", default = true })
  vim.api.nvim_set_hl(0, "ScmRef", { fg = "#4fc1ff", default = true })
  vim.api.nvim_set_hl(0, "ScmButton", { link = "Special", default = true })
end
colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

-- Display lines, entries and highlights from `git status --porcelain=v1 --branch`
-- and the graph from `git log --graph`
function M.parse(status, log)
  local lines, entries, hls = {}, {}, {}
  local staged, changes = {}, {}
  local branch, sync = "no branch", ""
  for _, l in ipairs(vim.split(status or "", "\n", { trimempty = true })) do
    if l:sub(1, 2) == "##" then
      local h = l:sub(4)
      branch = h:match("^No commits yet on (%S+)") or h:match("^(%S-)%.%.%.") or h:match("^(%S+)") or h
      local ahead, behind = h:match("ahead (%d+)"), h:match("behind (%d+)")
      if ahead or behind then
        sync = ("  ↑%s ↓%s"):format(ahead or 0, behind or 0)
      end
    else
      local x, y, path = l:sub(1, 1), l:sub(2, 2), l:sub(4)
      path = path:gsub("^.* %-> ", ""):gsub('^"(.*)"$', "%1") -- renames: the new name
      if x == "?" then
        table.insert(changes, { kind = "file", code = "U", path = path, staged = false })
      else
        if x ~= " " then
          table.insert(staged, { kind = "file", code = x, path = path, staged = true })
        end
        if y ~= " " then
          table.insert(changes, { kind = "file", code = y, path = path, staged = false })
        end
      end
    end
  end
  state.staged, state.changes = #staged, #changes

  local function add(text, entry, marks)
    lines[#lines + 1] = text
    entries[#lines] = entry
    for _, m in ipairs(marks or {}) do
      hls[#hls + 1] = { #lines - 1, m[1], m[2], m[3] } -- row, start col, end col (-1: line end), group
    end
  end

  add("  " .. branch .. sync, { kind = "branch" }, { { 0, -1, "Title" } })
  local commit_label = #staged > 0 and ("  ✓ Commit %d staged"):format(#staged)
    or (#changes > 0 and ("  ✓ Commit all %d changes"):format(#changes) or "  ✓ Commit")
  add(commit_label, { kind = "commit_box" }, { { 0, -1, "ScmButton" } })

  local function file_line(e)
    local path = e.path:gsub("/$", "") -- an untracked folder ends with /
    local name, dir = vim.fs.basename(path), vim.fs.dirname(path)
    dir = (dir == "." or dir == "") and "" or ("  " .. dir)
    local text = ("   %s  %s%s"):format(e.code, name, dir)
    add(text, e, { { 3, 4, CODE_HL[e.code] or "ScmModified" }, { 6 + #name, -1, "Comment" } })
  end
  if #staged > 0 then
    add("")
    add((" STAGED CHANGES  %d"):format(#staged), nil, { { 0, -1, "Special" } })
    for _, e in ipairs(staged) do
      file_line(e)
    end
  end
  add("")
  add((" CHANGES  %d"):format(#changes), nil, { { 0, -1, "Special" } })
  for _, e in ipairs(changes) do
    file_line(e)
  end
  if #staged == 0 and #changes == 0 then
    add("   nothing to commit", nil, { { 0, -1, "Comment" } })
  end

  -- GRAPH: each commit line is "<graph>\31<sha>\31<subject>\31<refs>"
  local graph = vim.split(log or "", "\n", { trimempty = true })
  if #graph > 0 then
    add("")
    add(" GRAPH", nil, { { 0, -1, "Special" } })
    for _, l in ipairs(graph) do
      local g, sha, subject, refs = l:match("^(.-)\31(%x+)\31(.-)\31(.*)$")
      if g then
        g = g:gsub("%*", "●")
        refs = refs:gsub("HEAD %-> ", ""):gsub("refs/heads/", "")
        local text = " " .. g .. subject
        local marks = { { 1, 1 + #g, "Comment" } }
        if refs ~= "" then
          marks[#marks + 1] = { #text + 2, -1, "ScmRef" }
          text = text .. "  " .. refs
        end
        add(text, { kind = "commit", sha = sha, subject = subject }, marks)
      else
        add(" " .. l, nil, { { 0, -1, "Comment" } })
      end
    end
  end
  add("")
  add(HINT, nil, { { 0, -1, "Comment" } })
  return lines, entries, hls
end

local function render(lines, entries, hls)
  if state.collapsed then
    return -- folded to its title; filled again when it opens
  end
  state.entries = entries
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    local row, s, e, group = h[1], h[2], h[3], h[4]
    local len = #lines[row + 1]
    pcall(vim.api.nvim_buf_set_extmark, state.buf, ns, row, math.min(s, len),
      { hl_group = group, end_col = e < 0 and len or math.min(e, len), strict = false })
  end
  pcall(vim.api.nvim_win_set_cursor, state.win, { math.min(cursor[1], #lines), 0 })
end

function M.refresh()
  if not valid() or state.busy then
    return
  end
  if not root() then
    render({ " Not a git repository", "", HINT }, {}, {})
    return
  end
  state.busy = true
  git({ "status", "--porcelain=v1", "--branch", "-uall" }, function(status)
    git({ "log", "--graph", "--all", "--date-order", "-n", "40", "--decorate=short", "--format=%x1f%h%x1f%s%x1f%D" }, function(log)
      state.busy = false
      if valid() then
        render(M.parse(status.stdout, log.code == 0 and log.stdout or ""))
      end
    end)
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

local function run(what, args)
  vim.notify(what .. "...", vim.log.levels.INFO, { title = "Git" })
  git(args, report(what))
end

local function toggle_stage()
  local e = current_entry()
  if not e or e.kind ~= "file" then
    return
  end
  if e.staged then
    git({ "restore", "--staged", "--", e.path }, function() M.refresh() end)
  else
    git({ "add", "--", e.path }, function() M.refresh() end)
  end
end

local function commit()
  local function ask()
    vim.ui.input({ prompt = "Commit message: " }, function(msg)
      if msg and vim.trim(msg) ~= "" then
        git({ "commit", "-m", msg }, report("Commit"))
      end
    end)
  end
  if state.staged == 0 and state.changes > 0 then
    -- like VS Code: nothing staged commits every change
    git({ "add", "-A" }, function(res)
      if res.code == 0 then
        ask()
      else
        report("Stage")(res)
      end
    end)
  else
    ask()
  end
end

local function sync()
  vim.notify("Syncing...", vim.log.levels.INFO, { title = "Git" })
  git({ "pull" }, function(res)
    if res.code ~= 0 then
      return report("Pull")(res)
    end
    git({ "push" }, report("Sync"))
  end)
end

local function branches()
  Snacks.picker.git_branches({ title = "Switch branch  (Ctrl+A new · Ctrl+X delete)" })
end

local function new_branch()
  vim.ui.input({ prompt = "New branch name: " }, function(name)
    if name and vim.trim(name) ~= "" then
      git({ "switch", "-c", vim.trim(name) }, report("New branch " .. vim.trim(name)))
    end
  end)
end

-- the code area window (right of the side panels), created when only panels are open
local function editor_win()
  local wins = require("config.tabs").editor_wins()
  for _, w in ipairs(wins) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "" then
      return w
    end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_dashboard" then
      return w -- the start screen is the code area
    end
  end
  if wins[1] then
    return wins[1]
  end
  -- only side panels and terminals: a new code area left of the terminal (Claude),
  -- never inside the sidebar
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative == "" and vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "terminal"
      and vim.api.nvim_win_get_position(w)[2] > 0 then
      return vim.api.nvim_open_win(vim.api.nvim_create_buf(true, false), true, { split = "left", win = w })
    end
  end
  vim.cmd("botright vnew")
  return vim.api.nvim_get_current_win()
end

-- read-only text (a commit, a deleted file) in the code area
local function show_text(name, lines, ft)
  vim.api.nvim_set_current_win(editor_win())
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft
  pcall(vim.api.nvim_buf_set_name, buf, name)
  vim.api.nvim_win_set_buf(0, buf)
  vim.cmd.stopinsert()
end

local function open_file(e)
  e = e or current_entry()
  if not e or e.kind ~= "file" then
    return
  end
  vim.api.nvim_set_current_win(editor_win())
  vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(root(), e.path)))
end

local function lines_of(res)
  local out = vim.split(res.stdout or "", "\n")
  if out[#out] == "" then
    table.remove(out)
  end
  return out
end

-- A file's changes in one panel, like VS Code's inline diff view: the file itself
-- (editable), new and changed lines in green, the removed ones in red above where
-- they were. It stays one tab: Ctrl+W closes it like any file. The removed lines go
-- away once the file is closed or shown elsewhere. New files just open; deleted ones
-- show what was removed.
local inline_ns = vim.api.nvim_create_namespace("vscode_scm_inline")

local function draw_inline(buf)
  local base = vim.b[buf].vscode_inline_base
  if not base or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, inline_ns, 0, -1)
  local now = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local diff = vim.text and vim.text.diff or vim.diff
  local hunks = diff(table.concat(base, "\n") .. "\n", table.concat(now, "\n") .. "\n",
    { result_type = "indices", algorithm = "histogram" })
  local width = vim.o.columns
  for _, h in ipairs(hunks) do
    local a, ca, b, cb = h[1], h[2], h[3], h[4]
    for l = b, b + cb - 1 do
      vim.api.nvim_buf_set_extmark(buf, inline_ns, l - 1, 0, { line_hl_group = "VSCodeInlineAdd", priority = 5 })
    end
    if ca > 0 then
      local virt = {}
      for l = a, a + ca - 1 do
        local text = (base[l] or ""):gsub("\t", string.rep(" ", vim.bo[buf].tabstop))
        virt[#virt + 1] = { { text .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(text), 0)), "VSCodeInlineDelete" } }
      end
      -- removed lines go above the lines that replaced them, or below the line
      -- before them when nothing replaced them
      if cb > 0 or b == 0 then
        local row = math.max(b - 1, 0)
        vim.api.nvim_buf_set_extmark(buf, inline_ns, row, 0, { virt_lines = virt, virt_lines_above = true })
        if row == 0 then
          -- above the first line they only show with the view scrolled onto them
          for _, w in ipairs(vim.fn.win_findbuf(buf)) do
            vim.api.nvim_win_call(w, function()
              if vim.fn.line("w0") == 1 then
                vim.fn.winrestview({ topline = 1, topfill = #virt })
              end
            end)
          end
        end
      else
        vim.api.nvim_buf_set_extmark(buf, inline_ns, math.min(b, #now) - 1, 0, { virt_lines = virt })
      end
    end
  end
end

local function stop_inline(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.b[buf].vscode_inline_base = nil
    vim.api.nvim_buf_clear_namespace(buf, inline_ns, 0, -1)
    pcall(vim.api.nvim_del_augroup_by_name, "vscode_scm_inline_" .. buf)
  end
end

local function set_inline_colors()
  vim.api.nvim_set_hl(0, "VSCodeInlineAdd", { bg = "#1e3a28", default = true })
  vim.api.nvim_set_hl(0, "VSCodeInlineDelete", { bg = "#4b1e22", fg = "#d7a6a6", default = true })
end
set_inline_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_inline_colors })

local function diff(e)
  if e.code == "U" or (e.code == "A" and e.staged) then
    return open_file(e)
  end
  if e.code == "D" then
    return git({ "diff", e.staged and "--cached" or "HEAD", "--", e.path }, function(res)
      show_text("deleted: " .. e.path, lines_of(res), "diff")
    end)
  end
  git({ "show", (e.staged and "HEAD:" or ":") .. e.path }, function(old)
    open_file(e)
    if old.code ~= 0 then
      return
    end
    local buf = vim.api.nvim_get_current_buf()
    vim.b[buf].vscode_inline_base = lines_of(old)
    draw_inline(buf)
    local group = vim.api.nvim_create_augroup("vscode_scm_inline_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = group,
      buffer = buf,
      callback = function() draw_inline(buf) end,
    })
    vim.api.nvim_create_autocmd({ "BufWinLeave", "BufDelete" }, {
      group = group,
      buffer = buf,
      callback = function() stop_inline(buf) end,
    })
  end)
end

local function show_commit(e)
  git({ "show", "--stat", "--patch", "--format=commit %H%nAuthor: %an <%ae>%nDate:   %ad%n%n    %s%n%n%b", e.sha }, function(res)
    show_text("commit " .. e.sha, vim.split(res.stdout or "", "\n"), "git")
  end)
end

local function discard()
  local e = current_entry()
  if not e or e.kind ~= "file" then
    return
  end
  if e.staged then
    return vim.notify("Unstage it first (s)", vim.log.levels.WARN, { title = "Git" })
  end
  local untracked = e.code == "U"
  local question = untracked and ("Delete the new file %s? It is not in git, it cannot be recovered."):format(e.path)
    or ("Discard the changes in %s?"):format(e.path)
  if vim.fn.confirm(question, "&Discard\n&Cancel", 2) ~= 1 then
    return
  end
  if untracked then
    vim.fn.delete(vim.fs.joinpath(root(), e.path), "rf")
    M.refresh()
  else
    git({ "restore", "--", e.path }, function() M.refresh() end)
  end
end

-- Enter or a click: what the line under it does
local function activate(e)
  e = e or current_entry()
  if not e then
    return
  end
  if e.kind == "branch" then
    branches()
  elseif e.kind == "commit_box" then
    commit()
  elseif e.kind == "file" then
    diff(e)
  elseif e.kind == "commit" then
    show_commit(e)
  end
end

-- header buttons (winbar), clicked: minwid is the button number
local BUTTONS = {
  { icon = "", run = commit, desc = "Commit" },
  { icon = "󰑓", run = function() M.refresh() end, desc = "Refresh" },
  { icon = "󰓦", run = sync, desc = "Sync (pull + push)" },
  { icon = "", run = branches, desc = "Branches" },
  { icon = "󰊢", run = function() Snacks.lazygit() end, desc = "Lazygit" },
}
M.buttons = BUTTONS
function _G.VSCodeScmButton(minwid)
  local b = BUTTONS[minwid]
  if b then
    vim.schedule(b.run)
  end
end
-- a click on the title folds the section to that title line, like a VS Code sidebar
-- section; a click on the folded title opens it again
function _G.VSCodeScmToggle()
  vim.schedule(function() M.toggle_collapsed() end)
end
local WINBAR = (function()
  local parts = { "%0@v:lua.VSCodeScmToggle@%#Title# ▾ SOURCE CONTROL%*%X%=" }
  for i, b in ipairs(BUTTONS) do
    parts[#parts + 1] = ("%%%d@v:lua.VSCodeScmButton@%%#ScmButton# %s %%*%%X"):format(i, b.icon)
  end
  return table.concat(parts) .. " "
end)()

function M.toggle_collapsed()
  if not valid() then
    return
  end
  if state.collapsed then
    state.collapsed = false
    vim.wo[state.win].winbar = WINBAR
    vim.api.nvim_win_set_height(state.win, state.open_height or 12)
    M.refresh()
    return
  end
  state.open_height = vim.api.nvim_win_get_height(state.win)
  state.collapsed = true
  state.entries = {}
  vim.wo[state.win].winbar = "" -- a 1-line panel has no room for a header
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { " ▸ SOURCE CONTROL" })
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(state.buf, ns, 0, 0, { end_col = #" ▸ SOURCE CONTROL", hl_group = "Title" })
  vim.api.nvim_win_set_height(state.win, 1)
end

-- One click selects the line, a double click opens it (diff, commit, branches):
-- a click in passing never opens anything. The header buttons are clicks on row 0
-- and stay with Neovim.
local function line_under_mouse(pos)
  return valid() and pos.winid == state.win and pos.line >= 1 and pos.line <= vim.api.nvim_buf_line_count(state.buf)
end
table.insert(require("config.scrollbar").on_click, function(pos)
  if not line_under_mouse(pos) then
    return false
  end
  if state.collapsed then
    vim.schedule(M.toggle_collapsed)
    return true
  end
  vim.cmd.stopinsert() -- coming from a file being typed in: the panel is never in typing mode
  vim.api.nvim_set_current_win(state.win)
  vim.api.nvim_win_set_cursor(state.win, { pos.line, 0 })
  return true
end)

-- Right-click menu of a line, like VS Code's (lua/config/menu.lua shows it)
local function menu_items(e)
  if e and e.kind == "file" then
    local items = {
      { "Open Changes", function() diff(e) end },
      { "Open File", function() open_file(e) end },
      "-",
      { e.staged and "Unstage Changes" or "Stage Changes", toggle_stage },
    }
    if not e.staged then
      items[#items + 1] = { "Discard Changes", discard }
    end
    items[#items + 1] = "-"
    items[#items + 1] = { "Copy Path", function() vim.fn.setreg("+", vim.fs.joinpath(root(), e.path)) end }
    return items
  elseif e and e.kind == "commit" then
    return {
      { "Open Commit", function() show_commit(e) end },
      { "Copy Commit Hash", function() vim.fn.setreg("+", e.sha) end },
    }
  end
  return {
    { "Commit", commit },
    { "Stage All Changes", function() git({ "add", "-A" }, function() M.refresh() end) end },
    { "Unstage All Changes", function() git({ "restore", "--staged", "." }, function() M.refresh() end) end },
    "-",
    { "Sync (Pull + Push)", sync },
    { "Switch Branch...", branches },
    { "New Branch...", new_branch },
  }
end
local function context_menu()
  local pos = vim.fn.getmousepos()
  if line_under_mouse(pos) then
    vim.api.nvim_win_set_cursor(state.win, { pos.line, 0 })
  end
  require("config.menu").open(menu_items(current_entry()))
end
-- from any window: the right click focuses the panel first
table.insert(require("config.scrollbar").on_right_click, function(pos)
  if not valid() or pos.winid ~= state.win then
    return false
  end
  vim.cmd.stopinsert()
  vim.api.nvim_set_current_win(state.win)
  context_menu()
  return true
end)

local function map_keys(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "s", toggle_stage, o)
  vim.keymap.set("n", "<space>", toggle_stage, o)
  vim.keymap.set("n", "a", function() git({ "add", "-A" }, function() M.refresh() end) end, o)
  vim.keymap.set("n", "u", function() git({ "restore", "--staged", "." }, function() M.refresh() end) end, o)
  vim.keymap.set("n", "x", discard, o)
  vim.keymap.set("n", "c", commit, o)
  vim.keymap.set("n", "p", function() run("Push", { "push" }) end, o)
  vim.keymap.set("n", "P", function() run("Pull", { "pull" }) end, o)
  vim.keymap.set("n", "f", function() run("Fetch", { "fetch", "--all", "--prune" }) end, o)
  vim.keymap.set("n", "S", sync, o)
  vim.keymap.set("n", "b", branches, o)
  vim.keymap.set("n", "B", new_branch, o)
  vim.keymap.set("n", "o", function() open_file() end, o)
  vim.keymap.set("n", "<cr>", function()
    if state.collapsed then
      return M.toggle_collapsed()
    end
    activate()
  end, o)
  vim.keymap.set({ "n", "i", "v" }, "<2-LeftMouse>", function()
    vim.cmd.stopinsert()
    local pos = vim.fn.getmousepos()
    if line_under_mouse(pos) then
      activate(state.entries[pos.line])
    end
  end, o)
  vim.keymap.set("n", "r", M.refresh, o)
  vim.keymap.set("n", "g", function() Snacks.lazygit() end, o)
  vim.keymap.set("n", "?", function() vim.notify(table.concat(KEYS, "\n"), vim.log.levels.INFO, { title = "Git" }) end, o)
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
  local height = math.max(8, math.floor(vim.api.nvim_win_get_height(anchor) * 0.45))
  state.win = vim.api.nvim_open_win(state.buf, true, { split = "below", win = anchor, height = height })
  for opt, val in pairs({ number = false, relativenumber = false, signcolumn = "no", wrap = false,
    cursorline = true, winfixheight = true, winfixwidth = true, statuscolumn = "", foldcolumn = "0" }) do
    vim.wo[state.win][opt] = val
  end
  vim.wo[state.win].winbar = WINBAR
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
