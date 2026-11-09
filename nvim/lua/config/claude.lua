-- Claude Code keeps working on the same conversation, like the VS Code extension:
-- opening Claude in a folder where it was used before continues the latest
-- conversation instead of starting a new one each time. Alt+Shift+C (or
-- :ClaudeSessions) lists the folder's past conversations by name to pick one.
--
-- Conversations are always reopened by their id (claude --resume <id>). Claude's own
-- list and --continue compare the folder letter by letter, so a conversation started
-- from VS Code (c:\...) was "from a different directory" in nvim (C:\...).
local M = {}

local function load()
  require("lazy").load({ plugins = { "claudecode.nvim" } })
end

local function running()
  load()
  local ok, buf = pcall(function() return require("claudecode.terminal").get_active_terminal_bufnr() end)
  return ok and buf ~= nil
end

-- ~/.claude/projects/<folder with every non-alphanumeric character as "-">
function M.project_dir(cwd)
  local base = vim.env.CLAUDE_CONFIG_DIR or vim.fs.joinpath(vim.uv.os_homedir(), ".claude")
  return vim.fs.joinpath(base, "projects", ((cwd or vim.fn.getcwd()):gsub("[^%w]", "-")))
end

local function read_part(path, from_end, size)
  local f = io.open(path, "rb")
  if not f then
    return ""
  end
  local len = f:seek("end")
  f:seek("set", from_end and math.max(len - size, 0) or 0)
  local data = f:read(size) or ""
  f:close()
  return data
end

local function decode(s)
  local ok, v = pcall(vim.json.decode, '"' .. s .. '"')
  return ok and v or s
end

-- The name Claude shows for a conversation: the one given with /rename, else its
-- automatic title, else the first message
local function title_of(path)
  local tail = read_part(path, true, 262144)
  local best
  for kind, value in tail:gmatch('"(%a+[Tt]itle)":"(.-[^\\])"') do
    if kind == "customTitle" or not best then
      best = value
    end
  end
  if not best then
    best = tail:match('"type":"summary","summary":"(.-[^\\])"')
  end
  if not best then
    local head = read_part(path, false, 131072)
    best = head:match('"role":"user","content":"(.-[^\\])"')
      or head:match('"role":"user","content":%[{"type":"text","text":"(.-[^\\])"')
  end
  best = best and vim.trim((decode(best):gsub("%s+", " "))) or ""
  return best ~= "" and best or "(no messages)"
end

-- This folder's conversations, newest first. Windows file names ignore case, so
-- c:\... and C:\... share the same folder of conversations.
function M.list(cwd)
  local out = {}
  for _, path in ipairs(vim.fn.glob(vim.fs.joinpath(M.project_dir(cwd), "*.jsonl"), false, true)) do
    local stat = vim.uv.fs_stat(path)
    if stat and stat.size > 0 then
      out[#out + 1] = { id = vim.fn.fnamemodify(path, ":t:r"), path = path, mtime = stat.mtime.sec }
    end
  end
  table.sort(out, function(a, b) return a.mtime > b.mtime end)
  return out
end

local function open_with(args)
  load()
  vim.cmd("ClaudeCodeFocus " .. args)
end

-- Show / focus Claude; started here for the first time, it reopens the folder's
-- latest conversation (a new one only when there is none)
function M.focus()
  if running() then
    return open_with("")
  end
  local last = M.list()[1]
  open_with(last and ("--resume " .. last.id) or "")
end

local function ago(sec)
  local d = os.time() - sec
  if d < 3600 then
    return math.max(1, math.floor(d / 60)) .. " min ago"
  elseif d < 86400 then
    return math.floor(d / 3600) .. " h ago"
  end
  return os.date("%d/%m/%Y", sec)
end

-- Pick one of this folder's conversations by name (type to search)
function M.sessions()
  local items = {}
  for _, s in ipairs(M.list()) do
    s.title = title_of(s.path)
    s.when = ago(s.mtime)
    s.text = s.title .. " " .. s.id
    items[#items + 1] = s
  end
  if #items == 0 then
    vim.notify("No Claude conversations in this folder yet", vim.log.levels.INFO)
    return
  end
  Snacks.picker({
    title = "Claude conversations",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return { { ("%-14s "):format(item.when), "SnacksPickerComment" }, { item.title, "SnacksPickerLabel" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.schedule(function()
        if running() then
          require("claudecode.terminal").close()
        end
        vim.schedule(function() open_with("--resume " .. item.id) end)
      end)
    end,
  })
end

vim.api.nvim_create_user_command("ClaudeSessions", M.sessions, { desc = "Reopen a past Claude conversation" })

return M
