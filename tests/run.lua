-- Headless test suite for the nvim config.
-- Run from the repo root, with the config installed (see install.sh / install.ps1):
--   nvim --headless -c "luafile tests/run.lua"
-- Exits 0 when every test passes, 1 when any fails, 2 on timeout.
vim.env.NVIM_NO_SESSION = "1"

local passed, failed = 0, 0
local finished = false

local function out(msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end

local function finish(code)
  if finished then
    return
  end
  finished = true
  pcall(function() vim.fn.delete(vim.fs.joinpath(vim.fn.getcwd(), "tests", ".tmp"), "rf") end)
  vim.cmd(code == 0 and "qall!" or ("cquit " .. code))
end

-- never hang CI
vim.defer_fn(function()
  out("TIMEOUT")
  finish(2)
end, 300000)

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    out("ok   " .. name)
  else
    failed = failed + 1
    out("FAIL " .. name .. ": " .. tostring(err))
  end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(what or "value", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function truthy(v, what)
  if not v then
    error((what or "value") .. " is falsy", 2)
  end
end

local root = vim.fn.getcwd()
local scratch = vim.fs.joinpath(root, "tests", ".tmp")
vim.fn.mkdir(scratch, "p")

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines or { "x" }, path)
end

-- ---------------------------------------------------------------- startup
local function started()
  return vim.fn.maparg("<A-p>", "n") ~= ""
end
local ok_start = pcall(function()
  vim.api.nvim_exec_autocmds("UIEnter", {})
  vim.wait(15000, started, 50)
  if not started() then
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.wait(15000, started, 50)
  end
  -- plugins that start on VimEnter (which-key) never see it in a -c script
  vim.api.nvim_exec_autocmds("VimEnter", {})
  vim.wait(200, function() return false end, 10)
end)
if not ok_start or not started() then
  out("FAIL startup: the config did not load its keymaps (is it installed and linked?)")
  finish(1)
  return
end
vim.o.shortmess = vim.o.shortmess .. "I"

-- Nothing may block waiting for a person: input, selection and notifications are stubbed
local H = { input = nil, notes = {}, terminal = 0, lazygit = 0 }
vim.notify = function(msg) H.notes[#H.notes + 1] = tostring(msg) end
vim.ui.input = function(_, cb) cb(H.input) end
vim.ui.select = function(items, _, cb) cb(items[1], 1) end

-- ------------------------------------------------------------------ links
test("links.resolve", function()
  local links = require("config.links")
  local proj = vim.fs.joinpath(scratch, "proj")
  local deep = vim.fs.joinpath(proj, "src", "app", "features", "management")
  write(vim.fs.joinpath(deep, "x.ts"))
  write(vim.fs.joinpath(proj, "Makefile"))
  local want = vim.fs.normalize(vim.fs.joinpath(deep, "x.ts"))

  eq(links.resolve("src/app/features/management/x.ts", proj), want, "relative path")
  eq(links.resolve("src\\app\\features\\management\\x.ts", proj), want, "backslash path")
  eq(links.resolve("src\\app\\features\\managem…\\x.ts", proj), want, "Claude-shortened path")
  eq(links.resolve("src/app/features/management/nope.ts", proj), nil, "missing file")
  eq(links.resolve("82.5", proj), nil, "number")
  eq(links.resolve("src/app/features/management", proj), nil, "directory")

  -- absolute path, with and without a :line suffix handled by the caller
  eq(links.resolve(want, proj), want, "absolute path")

  -- a path relative to the cwd, found from another folder name printed
  eq(links.resolve("management/x.ts", proj), want, "path relative to a sub folder")

  -- a file without extension still resolves when the path is explicit
  eq(links.resolve("./Makefile", proj), vim.fs.normalize(vim.fs.joinpath(proj, "Makefile")), "file without extension")
end)

test("links.resolve ~ home", function()
  local links = require("config.links")
  local home = vim.uv.os_homedir()
  local name = ("dotfiles-test-%d.txt"):format(vim.uv.hrtime() % 1000000)
  local path = vim.fs.joinpath(home, name)
  local f = io.open(path, "w")
  if not f then
    -- home is not writable: only the "does not exist" side can be checked
    eq(links.resolve("~/" .. name, root), nil, "missing home file")
    return
  end
  f:write("x")
  f:close()
  local ok, err = pcall(function()
    eq(links.resolve("~/" .. name, root), vim.fs.normalize(path), "home path")
    eq(links.resolve("~\\" .. name, root), vim.fs.normalize(path), "home path with backslash")
  end)
  os.remove(path)
  if not ok then
    error(err, 0)
  end
end)

-- --------------------------------------------------------------- sessions
test("sessions.list", function()
  local sessions = require("config.sessions")
  local persistence = require("persistence")
  local real = vim.fs.joinpath(scratch, "project")
  vim.fn.mkdir(real, "p")
  local in_tmp = vim.fs.joinpath(vim.uv.os_tmpdir(), ("dotfiles-test-%d"):format(vim.uv.hrtime() % 1000000))
  vim.fn.mkdir(in_tmp, "p")
  local missing = vim.fs.joinpath(scratch, "does-not-exist")

  local function session_file(dir, branch)
    local name = dir:gsub("[\\/:]+", "%%") .. (branch and ("%%" .. branch:gsub("[\\/:]+", "%%")) or "") .. ".vim"
    local path = vim.fs.joinpath(scratch, "sessions", name)
    write(path, { "\" fake session" })
    return path
  end
  local fake = {
    session_file(real),
    session_file(in_tmp),
    session_file(missing),
    session_file(real, "feat/x"),
  }

  local original = persistence.list
  persistence.list = function() return fake end
  local ok, err = pcall(function()
    local list = sessions.list()
    local seen = {}
    for _, s in ipairs(list) do
      seen[#seen + 1] = vim.fs.normalize(s.dir) .. "|" .. (s.branch or "")
    end
    local norm_real = vim.fs.normalize(real)
    eq(#list, 2, "kept sessions (" .. table.concat(seen, ", ") .. ")")
    local plain, branch
    for _, s in ipairs(list) do
      if s.branch then branch = s else plain = s end
    end
    truthy(plain and vim.fs.normalize(plain.dir):lower() == norm_real:lower(), "plain session decodes to the folder")
    truthy(branch and vim.fs.normalize(branch.dir):lower() == norm_real:lower(), "branch session decodes to the folder")
    eq(branch.branch, "feat/x", "decoded branch")
    eq(plain.name, "project", "session name")
    eq(#sessions.list(1), 1, "max")
  end)
  persistence.list = original
  vim.fn.delete(in_tmp, "rf")
  if not ok then
    error(err, 0)
  end
end)

-- -------------------------------------------------------------- shortcuts
local NO_FORWARD = { WT_SESSION = false, TERM_PROGRAM = false, WEZTERM_PANE = false, NVIM_FORCE_MAC = false }
-- Clear every forwarding variable, set `extra`, run fn, restore. The OS is reported as
-- Linux (Cmd labels only come from NVIM_FORCE_MAC), so the macOS runner sees the same.
local function run_env(extra, fn)
  local saved = {}
  for k in pairs(NO_FORWARD) do
    saved[k] = vim.env[k]
    vim.env[k] = nil
  end
  for k, v in pairs(extra or {}) do
    vim.env[k] = v
  end
  local real_uname = vim.uv.os_uname
  vim.uv.os_uname = function() return vim.tbl_extend("force", real_uname(), { sysname = "Linux" }) end
  local ok, err = pcall(fn)
  vim.uv.os_uname = real_uname
  for k, v in pairs(saved) do
    vim.env[k] = v
  end
  if not ok then
    error(err, 0)
  end
end

test("shortcuts labels", function()
  local sc = require("config.shortcuts")
  local entry = { keys = "Ctrl+Shift+P", alt = "Alt+P" }
  local plain = { keys = "Ctrl+P" }
  run_env({ WT_SESSION = "x" }, function()
    eq(sc.entry_label(entry), "Ctrl+Shift+P", "Windows Terminal")
  end)
  run_env({}, function()
    eq(sc.entry_label(entry), "Alt+P", "no forwarding")
    eq(sc.entry_label(plain), "Ctrl+P", "entry without alt keeps Ctrl")
  end)
  run_env({ NVIM_FORCE_MAC = "1", TERM_PROGRAM = "WezTerm" }, function()
    eq(sc.entry_label(entry), "Cmd+Shift+P", "WezTerm on a Mac")
  end)
  run_env({ NVIM_FORCE_MAC = "1", TERM_PROGRAM = "Apple_Terminal" }, function()
    eq(sc.entry_label(entry), "Option+P", "Terminal.app")
    local label = sc.entry_label(plain)
    truthy(not label:find("Cmd"), "no Cmd where it never arrives")
    eq(label, "Ctrl+P", "plain Ctrl key in Terminal.app")
  end)
  -- forwards() reflects the environment
  run_env({ WEZTERM_PANE = "1" }, function() eq(sc.forwards(), true, "forwards in WezTerm") end)
  run_env({}, function() eq(sc.forwards(), false, "does not forward") end)
  eq(type(sc.nerd_font()), "boolean", "nerd_font")
end)

test("shortcuts.row widths", function()
  local sc = require("config.shortcuts")
  local keys = sc.dashboard_keys()
  truthy(#keys > 5, "dashboard keys")
  local width
  for _, k in ipairs(keys) do
    local w = 0
    local leader = false
    for _, chunk in ipairs(k.desc) do
      w = w + vim.fn.strdisplaywidth(chunk[1])
      if chunk[1]:find("·", 1, true) then
        leader = true
      end
    end
    truthy(leader, "leader dots in row " .. tostring(k.key))
    width = width or w
    eq(w, width, "display width of row " .. tostring(k.key))
  end
end)

-- ---------------------------------------------------------------- keymaps
test("keymaps exist", function()
  local function mapped(lhs, mode)
    return vim.fn.maparg(lhs, mode) ~= ""
  end
  for _, lhs in ipairs({ "<C-p>", "<A-p>", "<A-c>", "<A-k>", "<C-y>", "<C-k>v", "<C-k><C-v>" }) do
    for _, mode in ipairs({ "n", "i" }) do
      truthy(mapped(lhs, mode), lhs .. " in " .. mode)
    end
  end
  for _, mode in ipairs({ "n", "i", "t" }) do
    truthy(mapped("<C-S-v>", mode), "<C-S-v> in " .. mode)
  end
  truthy(mapped("<C-v>", "t"), "<C-v> in t")
  truthy(not mapped("<A-v>", "t"), "<A-v> must not be mapped in terminal mode")
  truthy(vim.fn.maparg("<C-a>", "n"):find("ggVG", 1, true), "<C-a> selects all")
end)

-- ----------------------------------------------------------- start screen
test("start screen fits the window", function()
  local lines, columns = vim.o.lines, vim.o.columns
  local ok, err = pcall(function()
    vim.o.columns = 140
    for _, height in ipairs({ 12, 20, 30, 45 }) do
      vim.o.lines = height
      vim.cmd("enew")
      local dash = Snacks.dashboard()
      local win = vim.api.nvim_get_current_win()
      local buf
      vim.wait(2000, function()
        buf = vim.api.nvim_win_get_buf(win)
        return vim.bo[buf].filetype == "snacks_dashboard" and vim.api.nvim_buf_line_count(buf) > 1
      end, 20)
      eq(vim.bo[buf].filetype, "snacks_dashboard", "dashboard buffer at height " .. height)
      local count, win_height = vim.api.nvim_buf_line_count(buf), vim.api.nvim_win_get_height(win)
      truthy(count <= win_height, ("height %d: %d lines in a %d row window"):format(height, count, win_height))
      pcall(function() dash:close() end)
    end
  end)
  vim.o.lines, vim.o.columns = lines, columns
  pcall(vim.cmd, "silent! %bwipeout!")
  if not ok then
    error(err, 0)
  end
end)

-- --------------------------------------------------------------- markdown
test("markdown toggle", function()
  local md = vim.fs.joinpath(scratch, "note.md")
  write(md, { "# Heading", "", "Some **bold** text", "", "- item" })
  vim.cmd("silent! %bwipeout!")
  vim.cmd.edit(vim.fn.fnameescape(md))
  local buf = vim.api.nvim_get_current_buf()
  eq(vim.bo[buf].filetype, "markdown", "filetype")
  local markdown = require("config.markdown")
  eq(markdown.toggle(), true, "toggle on handled")
  eq(vim.b[buf].md_preview, true, "md_preview on")
  eq(vim.bo[buf].modifiable, false, "read only in preview")
  local marks
  vim.wait(5000, function()
    marks = #vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {})
    return marks > 0
  end, 50)
  truthy(marks > 0, "render-markdown drew extmarks")
  eq(markdown.toggle(), true, "toggle off handled")
  truthy(not vim.b[buf].md_preview, "md_preview off")
  eq(vim.bo[buf].modifiable, true, "editable again")
  vim.cmd.stopinsert()
  vim.cmd("silent! %bwipeout!")
end)

-- -------------------------------------------------------------- clipboard
test("clipboard.has_image returns a boolean", function()
  local r = require("config.clipboard").has_image()
  eq(type(r), "boolean", "has_image")
end)

-- ----------------------------------------------------------------- images
test("images open in the system viewer", function()
  -- a valid 1x1 PNG
  local png = vim.base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
  local path = vim.fs.joinpath(scratch, "pixel.png")
  vim.fn.mkdir(scratch, "p")
  local f = assert(io.open(path, "wb"))
  f:write(png)
  f:close()

  local opened
  local real_open, real_supports = vim.ui.open, Snacks.image.supports_terminal
  vim.ui.open = function(p)
    opened = p
    return {} -- a truthy handle: the fallback launcher must not run
  end
  Snacks.image.supports_terminal = function() return false end
  vim.cmd("silent! %bwipeout!")
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.wait(2000, function() return opened ~= nil end, 20)
    vim.wait(100, function() return false end, 20) -- let the scheduled cleanup run
    truthy(opened, "vim.ui.open was called")
    eq(vim.fs.normalize(opened):lower(), vim.fs.normalize(path):lower(), "opened path")
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      truthy(not line:find("PNG", 1, true), "binary text in the buffer")
    end
    truthy(vim.api.nvim_buf_get_name(0) ~= path, "the png buffer was left")
  end)
  vim.ui.open, Snacks.image.supports_terminal = real_open, real_supports
  vim.cmd("silent! %bwipeout!")
  if not ok then
    error(err, 0)
  end
end)

-- ===================================================== every command / key
-- Harness: nothing may block (input/select/notify stubbed), terminals and lazygit
-- are recorded instead of launched, and every run starts from one clean window.
local commands_run, keymaps_run, keys_fed = 0, 0, 0

local function recorder(name)
  local function f() H[name] = H[name] + 1 end
  return setmetatable({ open = f, toggle = f, get = function() end }, { __call = f })
end
Snacks.terminal = recorder("terminal")
Snacks.lazygit = recorder("lazygit")
local updates = require("config.updates")
updates.check = function(cb) cb(0) end -- no network: ":DotfilesUpdate" always finds nothing new

local work = vim.fs.joinpath(scratch, "work.txt")
local function cleanup()
  pcall(function()
    -- let whatever the last command opened (pickers, grug-far) settle before closing it
    vim.wait(150, function() return false end, 10)
    for _, p in ipairs(Snacks.picker.get()) do
      p:close()
    end
    vim.wait(1000, function() return #Snacks.picker.get() == 0 end, 10)
  end)
  pcall(function() require("config.scm").close() end)
  pcall(vim.cmd.stopinsert)
  pcall(vim.cmd, "silent! unmap <buffer>")
  -- leave multi-cursor mode (the "select all occurrences" key starts it)
  pcall(function()
    if vim.fn.exists("*vm#reset") == 1 then vim.fn["vm#reset"]() end
  end)
  vim.wait(30, function() return false end, 10)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative ~= "" then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  pcall(vim.cmd, "silent! only!")
  pcall(vim.cmd, "silent! %bwipeout!")
  vim.fn.writefile({ "one", "two", "three" }, work)
  vim.cmd.edit(vim.fn.fnameescape(work))
  vim.bo.filetype = "text"
  vim.wo.wrap = true
  pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
  -- opening a file schedules "ready to type" (insert mode): let it run, then go back to
  -- normal mode, where every key test starts
  vim.wait(60, function() return false end, 10)
  pcall(vim.cmd.stopinsert)
  H.input, H.notes, H.terminal, H.lazygit = nil, {}, 0, 0
end

local function flush()
  vim.api.nvim_feedkeys("", "mx", false)
  vim.wait(60, function() return false end, 10)
end

local function wins() return #vim.api.nvim_list_wins() end
local function wait_for(pred, ms)
  vim.wait(ms or 3000, pred, 20)
  return pred() and true or false
end
local function picker_is(p, name)
  local src = tostring(p.opts and p.opts.source or ""):lower()
  local title = tostring(p.opts and p.opts.title or ""):lower()
  return src == name or title:find(name, 1, true) ~= nil
end
local function has_picker(name)
  return wait_for(function()
    for _, p in ipairs(Snacks.picker.get()) do
      if picker_is(p, name) then return true end
    end
  end)
end
local function has_ft(ft)
  return wait_for(function()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == ft then return true end
    end
  end)
end
local function line1() return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] end
local function esc() vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false) end

-- What the command must do. `setup` runs first; `check(state)` after.
local function picker_check(name) return { check = function() truthy(has_picker(name), name .. " picker opened") end } end
local function ft_check(ft) return { check = function() truthy(has_ft(ft), ft .. " window opened") end } end
local function load_only(cmd, plugin)
  return {
    skip_run = true,
    check = function()
      pcall(function() require("lazy").load({ plugins = { plugin } }) end)
      truthy(vim.fn.exists(":" .. cmd) ~= 0, ":" .. cmd .. " exists (not launched)")
    end,
  }
end
local wins_plus_one = {
  setup = function(s) s.wins = wins() end,
  check = function(s) eq(wins(), s.wins + 1, "window count") end,
}

local EXPECT = {
  ["Open folder"] = picker_check("projects"),
  ["Browse folders"] = picker_check("open folder"),
  ["Find file"] = picker_check("files"),
  ["Recent files"] = picker_check("recent"),
  ["Search in project"] = picker_check("grep"),
  ["Command palette"] = picker_check("commands"),
  ["Problems panel"] = {
    setup = function()
      vim.diagnostic.set(vim.api.nvim_create_namespace("tests"), 0, { { lnum = 0, col = 0, message = "x" } })
    end,
    check = function() truthy(has_picker("diagnostics"), "diagnostics picker opened") end,
  },
  ["Claude Code"] = load_only("ClaudeCodeFocus", "claudecode.nvim"),
  ["Send file to Claude"] = load_only("ClaudeCodeAdd", "claudecode.nvim"),
  ["Sign in to Copilot (once)"] = load_only("Copilot", "copilot.lua"),
  ["Git (commit, push)"] = { check = function() eq(H.lazygit, 1, "lazygit launched") end },
  ["Git changes panel (opens under the explorer)"] = ft_check("vscode_scm"),
  ["Start screen (logo and shortcuts)"] = ft_check("snacks_dashboard"),
  ["Terminal (show / hide)"] = { check = function() eq(H.terminal, 1, "terminal toggled") end },
  ["New terminal"] = { check = function() eq(H.terminal, 1, "terminal opened") end },
  ["Go to the file explorer"] = ft_check("snacks_picker_list"),
  ["Split editor"] = wins_plus_one,
  ["Split right"] = wins_plus_one,
  ["Split below"] = wins_plus_one,
  ["Close panel"] = {
    setup = function(s) vim.cmd("vsplit") s.wins = wins() end,
    check = function(s) eq(wins(), s.wins - 1, "window count") end,
  },
  ["Go to line"] = {
    setup = function() H.input = "2" end,
    check = function() eq(vim.api.nvim_win_get_cursor(0)[1], 2, "cursor line") end,
  },
  ["Replace in file"] = ft_check("grug-far"),
  ["Replace in project"] = ft_check("grug-far"),
  ["Toggle word wrap"] = {
    setup = function(s) s.wrap = vim.wo.wrap end,
    check = function(s) eq(vim.wo.wrap, not s.wrap, "wrap") end,
  },
  ["Save (formats with Prettier), keeps typing"] = {
    setup = function() vim.cmd("normal! Ahello") end,
    check = function() eq(vim.bo.modified, false, "saved") end,
  },
  ["Toggle comment"] = {
    setup = function() vim.bo.filetype = "lua" end,
    check = function() truthy(line1():find("^%-%-"), "line commented: " .. line1()) end,
  },
  ["Duplicate line"] = { check = function() eq(vim.api.nvim_buf_line_count(0), 4, "line count") end },
  ["Update the dotfiles from GitHub"] = {
    check = function() truthy(table.concat(H.notes, "\n"):find("up to date", 1, true), "reports up to date") end,
  },
  ["Settings"] = {
    check = function()
      truthy(wait_for(function()
        for _, p in ipairs(Snacks.picker.get()) do
          if picker_is(p, "settings") and vim.fs.normalize(p.opts.cwd or "") == vim.fs.normalize(vim.fn.stdpath("config")) then
            return true
          end
        end
      end), "settings picker on the nvim config")
    end,
  },
}
EXPECT["File explorer (show / hide); Ctrl+Shift+E / Alt+E also from Claude"] = ft_check("snacks_picker_list")

local function run_case(name, fn_run, spec)
  spec = spec or {}
  test(name, function()
    cleanup()
    local state = {}
    if spec.setup then spec.setup(state) end
    if not spec.skip_run then
      local ok, err = pcall(fn_run)
      flush()
      if not ok then error("raised: " .. tostring(err), 0) end
    end
    if spec.check then spec.check(state) end
  end)
end

-- 1. every shortcut-list entry that has an action
for _, entry in ipairs(require("config.shortcuts").list) do
  if entry.run then
    local spec = EXPECT[entry.desc]
    if entry.desc == "All LazyVim commands (menu)" then
      -- which-key waits for a key: type Esc first
      spec = { skip_run = false }
      run_case("command: " .. entry.keys .. " " .. entry.desc, function()
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "t", false)
        entry.run()
      end, spec)
    else
      run_case("command: " .. entry.keys .. " " .. entry.desc, entry.run, spec)
    end
    if not (spec and spec.skip_run) then commands_run = commands_run + 1 end
  end
end

-- 2. every mapping described in keymaps.lua
local descs = {}
for line in io.lines(vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "config", "keymaps.lua")) do
  for d in line:gmatch('desc%s*=%s*"([^"]+)"') do descs[d] = true end
  for d in line:gmatch("desc%s*=%s*'([^']+)'") do descs[d] = true end
end
for i = 1, 3 do descs[("Focus editor %d"):format(i)] = true end -- built with string.format in the file
local found, todo = {}, {}
for _, mode in ipairs({ "n", "i", "v", "x", "s", "t" }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    if m.desc and descs[m.desc] then
      found[m.desc] = true
      if m.callback then todo[#todo + 1] = { mode = mode, map = m } end
    end
  end
end
test("keymaps.lua: every described mapping exists", function()
  local missing = {}
  for d in pairs(descs) do
    if not found[d] then missing[#missing + 1] = d end
  end
  table.sort(missing)
  eq(#missing, 0, "unmapped descriptions: " .. table.concat(missing, ", "))
end)
table.sort(todo, function(a, b)
  return (a.mode .. a.map.lhs) < (b.mode .. b.map.lhs)
end)
-- these launch the claude binary: only checked for existence
local SKIP_RUN = { ["Claude Code"] = true }
for _, t in ipairs(todo) do
  local m = t.map
  local name = ("keymap [%s] %s  %s"):format(t.mode, m.lhs, m.desc)
  if SKIP_RUN[m.desc] then
    test(name .. " (exists, not launched)", function() truthy(m.callback, "callback") end)
  else
    run_case(name, function() m.callback() end)
    keymaps_run = keymaps_run + 1
  end
end

-- 3. feed the real keys, the VS Code key and its universal Alt twin
local function picker_names()
  local names = {}
  for _, p in ipairs(Snacks.picker.get()) do
    names[#names + 1] = tostring(p.opts.source) .. ":" .. tostring(p.opts.title)
  end
  table.sort(names)
  return table.concat(names, ",")
end
local function feed(lhs)
  vim.api.nvim_feedkeys(vim.keycode(lhs), "mx", false)
  keys_fed = keys_fed + 1
  vim.wait(80, function() return false end, 10)
end

-- each case: keys that must have the same effect; `effect()` returns a comparable
-- string after feeding, `want(effect)` asserts the expected one
local function feed_case(label, keys, opts)
  test("keys: " .. label, function()
    local effects = {}
    for _, lhs in ipairs(keys) do
      cleanup()
      if opts.setup then opts.setup() end
      local before = opts.before and opts.before() or nil
      feed(lhs)
      local ok, eff = pcall(opts.effect, before)
      pcall(esc)
      if not ok then error(lhs .. ": " .. tostring(eff), 0) end
      effects[#effects + 1] = eff
      truthy(opts.want(eff), ("%s: unexpected effect %s"):format(lhs, vim.inspect(eff)))
    end
    for i = 2, #effects do
      eq(effects[i], effects[1], keys[i] .. " does what " .. keys[1] .. " does")
    end
  end)
end

local function picker_effect(name)
  return {
    effect = function() has_picker(name) return picker_names() end,
    want = function(e) return e:lower():find(name, 1, true) ~= nil end,
  }
end
local function with(base, extra) return vim.tbl_extend("force", base, extra) end
feed_case("<C-p>", { "<C-p>" }, picker_effect("files"))
feed_case("command palette <C-S-p> / <A-p>", { "<C-S-p>", "<A-p>" }, picker_effect("commands"))
feed_case("search <C-S-f> / <A-f>", { "<C-S-f>", "<A-f>" }, picker_effect("grep"))
feed_case("open folder <C-S-o> / <A-o>", { "<C-S-o>", "<A-o>" }, picker_effect("projects"))
feed_case("browse folders <C-S-k> / <A-k>", { "<C-S-k>", "<A-k>" }, picker_effect("open folder"))
feed_case("recent <C-S-r> / <A-r>", { "<C-S-r>", "<A-r>" }, picker_effect("recent"))
feed_case("problems <C-S-m> / <A-m>", { "<C-S-m>", "<A-m>" }, with(picker_effect("diagnostics"), {
  setup = function()
    vim.diagnostic.set(vim.api.nvim_create_namespace("tests"), 0, { { lnum = 0, col = 0, message = "x" } })
  end,
}))
feed_case("settings <C-,> / <A-,>", { "<C-,>", "<A-,>" }, picker_effect("settings"))
feed_case("shortcuts <F1>", { "<F1>" }, picker_effect("shortcuts"))
local explorer = {
  effect = function() return tostring(has_ft("snacks_picker_list")) end,
  want = function(e) return e == "true" end,
}
feed_case("explorer <C-b>", { "<C-b>" }, explorer)
feed_case("explorer <C-S-e> / <A-e>", { "<C-S-e>", "<A-e>" }, explorer)
feed_case("replace in project <C-S-h> / <A-h>", { "<C-S-h>", "<A-h>" }, {
  effect = function() return tostring(has_ft("grug-far")) end,
  want = function(e) return e == "true" end,
})
feed_case("split <C-\\>", { "<C-\\>" }, {
  before = wins,
  effect = function(before) return tostring(wins() - before) end,
  want = function(e) return e == "1" end,
})
feed_case("terminal <C-j>", { "<C-j>" }, {
  effect = function() return tostring(H.terminal) end,
  want = function(e) return e == "1" end,
})
local focus_first = {
  setup = function() vim.cmd("vsplit") vim.cmd("wincmd l") end,
  effect = function()
    local w = vim.api.nvim_get_current_win()
    return tostring(vim.api.nvim_win_get_position(w)[2])
  end,
  want = function(e) return e == "0" end,
}
feed_case("editor 1 <C-1> / <A-1>", { "<C-1>", "<A-1>" }, focus_first)
feed_case("explorer focus <C-0> / <A-0>", { "<C-0>", "<A-0>" }, {
  effect = function() has_ft("snacks_picker_list") return vim.bo.filetype end,
  want = function(e) return e == "snacks_picker_list" end,
})
feed_case("word wrap <A-z>", { "<A-z>" }, {
  before = function() return vim.wo.wrap end,
  effect = function(before) return tostring(vim.wo.wrap ~= before) end,
  want = function(e) return e == "true" end,
})
feed_case("go to line <C-g>", { "<C-g>" }, {
  setup = function() H.input = "3" end,
  effect = function() return tostring(vim.api.nvim_win_get_cursor(0)[1]) end,
  want = function(e) return e == "3" end,
})
feed_case("select line <C-l>", { "<C-l>" }, {
  effect = function() return vim.fn.mode() end,
  want = function(e) return e == "V" end,
})
feed_case("select all <C-a>", { "<C-a>" }, {
  effect = function() return vim.fn.mode() .. vim.fn.line(".") end,
  want = function(e) return e == "V3" end,
})
feed_case("undo / redo <C-z> then <C-y>", { "<C-z>" }, {
  setup = function() vim.cmd("normal! Ahello") end,
  effect = function()
    local undone = line1()
    feed("<C-y>")
    return undone .. "|" .. line1()
  end,
  want = function(e) return e == "one|onehello" end,
})
feed_case("redo <C-S-z>", { "<C-S-z>" }, {
  setup = function() vim.cmd("normal! Ahello") vim.cmd("undo") end,
  effect = function() return line1() end,
  want = function(e) return e == "onehello" end,
})
feed_case("comment <C-/> / <C-_>", { "<C-/>", "<C-_>" }, {
  setup = function() vim.bo.filetype = "lua" end,
  effect = function() return line1() end,
  want = function(e) return e:find("^%-%-") ~= nil end,
})
local md_toggle = {
  setup = function()
    local md = vim.fs.joinpath(scratch, "keys.md")
    write(md, { "# Title", "", "text" })
    vim.cmd.edit(vim.fn.fnameescape(md))
  end,
  effect = function() return tostring(vim.b.md_preview) end,
  want = function(e) return e == "true" end,
}
feed_case("markdown <C-k>v", { "<C-k>v" }, md_toggle)
feed_case("markdown <C-k><C-v>", { "<C-k><C-v>" }, md_toggle)
feed_case("markdown <A-v>", { "<A-v>" }, md_toggle)

-- ---------------------------------------------------------------- summary
cleanup()
out(("%d passed, %d failed; commands run: %d, keymaps executed: %d, key sequences fed: %d"):format(
  passed, failed, commands_run, keymaps_run, keys_fed))
finish(failed == 0 and 0 or 1)
