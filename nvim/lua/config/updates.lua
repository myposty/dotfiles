-- Updates for the dotfiles repository. On start it fetches in the background
-- (never blocks) and, when GitHub has newer commits, pulls them. Works the
-- same on Windows, macOS and Linux: it only needs git.
-- :DotfilesUpdate updates on demand.
local M = {}

-- The nvim config is a link into the repo (dotfiles/nvim); its real path finds the repo
function M.repo()
  if vim.env.DOTFILES_DIR then
    return vim.env.DOTFILES_DIR
  end
  local real = vim.uv.fs_realpath(vim.fn.stdpath("config"))
  if not real then
    return nil
  end
  local out = vim.fn.systemlist({ "git", "-C", real, "rev-parse", "--show-toplevel" })
  return vim.v.shell_error == 0 and out[1] or nil
end

-- The repo is public: no credentials, so it never opens the macOS keychain dialog
-- or a password prompt (credential helpers off, prompts off)
local function git(repo, args, cb)
  local cmd = { "git", "-c", "credential.helper=", "-C", repo }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true, env = { GIT_TERMINAL_PROMPT = "0", GCM_INTERACTIVE = "never" } }, function(res)
    vim.schedule(function()
      cb(res)
    end)
  end)
end

-- Calls cb(count, repo) with the number of new commits on the remote (0 when up to date)
function M.check(cb)
  local repo = M.repo()
  if not repo then
    return cb(0)
  end
  git(repo, { "fetch", "--quiet" }, function(fetch)
    if fetch.code ~= 0 then
      return cb(0, repo)
    end
    git(repo, { "rev-list", "--count", "HEAD..@{u}" }, function(res)
      cb(res.code == 0 and tonumber(vim.trim(res.stdout or "")) or 0, repo)
    end)
  end)
end

-- Restart to apply an update, coming back to the same place: folder, open files,
-- tabs, splits and the explorer. Uses :restart (Neovim 0.12+); otherwise nvim quits
-- and the `nvim` shell function from the installers opens it again.
local marker = vim.fs.joinpath(vim.fn.stdpath("state"), "dotfiles-restart.json")
local session = vim.fs.joinpath(vim.fn.stdpath("state"), "dotfiles-restart.vim")

local function bullets(changes)
  return table.concat(vim.tbl_map(function(c) return "• " .. c end, changes), "\n")
end

function M.restart(changes)
  local can_restart = vim.fn.exists(":restart") == 2 or vim.env.NVIM_RESTART_WRAPPER == "1"
  if not can_restart then
    vim.notify("Dotfiles updated:\n" .. bullets(changes) .. "\n\nClose nvim and open it again to use them.",
      vim.log.levels.WARN, { title = "Dotfiles", timeout = 20000 })
    return
  end
  local unsaved = vim.tbl_filter(function(b)
    return vim.bo[b].modified and vim.bo[b].buftype == ""
  end, vim.api.nvim_list_bufs())
  local function go()
    -- side panels and terminals are not files: close them, remember the explorer
    local explorer = false
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local b = vim.api.nvim_win_get_buf(w)
      local ft = vim.bo[b].filetype
      if ft == "snacks_picker_list" then
        explorer = true
      end
      if vim.bo[b].buftype ~= "" and #vim.api.nvim_list_wins() > 1 then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end
    local options = vim.o.sessionoptions
    vim.o.sessionoptions = "buffers,curdir,folds,tabpages,winsize"
    vim.cmd("mksession! " .. vim.fn.fnameescape(session))
    vim.o.sessionoptions = options
    vim.fn.mkdir(vim.fn.fnamemodify(marker, ":h"), "p")
    vim.fn.writefile({ vim.json.encode({ changes = changes, explorer = explorer }) }, marker)
    if vim.fn.exists(":restart") == 2 then
      vim.cmd("restart lua require('config.updates').resume()")
    else
      vim.cmd("qa!")
    end
  end
  local text = "Dotfiles updated:\n" .. bullets(changes)
  if #unsaved > 0 then
    vim.ui.select({ "Save my files and restart", "Restart later" },
      { prompt = text .. "\nRestart now to use the update?" }, function(choice)
        if choice == "Save my files and restart" then
          vim.cmd("silent! wall")
          go()
        end
      end)
    return
  end
  vim.notify(text .. "\n\nRestarting to apply it...", vim.log.levels.INFO, { title = "Dotfiles" })
  vim.defer_fn(go, 2500)
end

-- After the restart: the same folder, files and layout, then what changed
function M.resume()
  -- the shell function renames the marker before reopening, so a failure never loops
  local file = vim.fn.filereadable(marker .. ".resume") == 1 and marker .. ".resume" or marker
  local ok, info = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(file), "\n")) end)
  pcall(os.remove, marker)
  pcall(os.remove, marker .. ".resume")
  info = ok and info or {}
  if vim.fn.filereadable(session) == 1 then
    pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(session))
    pcall(os.remove, session)
  end
  vim.schedule(function()
    -- the explorer already opens on start: never end up with two
    if info.explorer and not require("config.sessions").explorer_open() then
      pcall(function() Snacks.explorer.open() end)
    end
    vim.notify("Dotfiles updated and nvim restarted:\n" .. bullets(info.changes or {}), vim.log.levels.INFO,
      { title = "Dotfiles", timeout = 10000 })
  end)
end

-- Pulls the new commits (fast-forward only, never overwrites local edits),
-- installs the plugin versions they pin, then restarts nvim to apply them
function M.apply(repo, done)
  repo = repo or M.repo()
  git(repo, { "rev-parse", "HEAD" }, function(before)
    local old = vim.trim(before.stdout or "")
    git(repo, { "pull", "--ff-only", "--quiet" }, function(res)
      if res.code ~= 0 then
        vim.notify("Could not update the dotfiles:\n" .. vim.trim(res.stderr or ""), vim.log.levels.ERROR, { title = "Dotfiles" })
        if done then
          done(false)
        end
        return
      end
      git(repo, { "log", "--format=%s", old .. "..HEAD" }, function(log)
        local changes = vim.split(vim.trim(log.stdout or ""), "\n", { trimempty = true })
        pcall(function()
          require("lazy").restore({ show = false, wait = true })
        end)
        if done then
          done(true)
        end
        M.restart(changes)
      end)
    end)
  end)
end

function M.prompt(count, repo)
  local what = count == 1 and "1 new update" or (count .. " new updates")
  vim.ui.select({ "Update now", "Later" }, { prompt = "Dotfiles: " .. what .. " available" }, function(choice)
    if choice == "Update now" then
      M.apply(repo)
    end
  end)
end

vim.api.nvim_create_user_command("DotfilesUpdate", function()
  M.check(function(count, repo)
    if count > 0 then
      M.apply(repo)
    else
      vim.notify("Dotfiles are up to date.", vim.log.levels.INFO, { title = "Dotfiles" })
    end
  end)
end, { desc = "Update the dotfiles from GitHub" })

-- Background update a few seconds after start (only with a screen, never in headless
-- runs): new commits are pulled without asking (fast-forward only, local edits are
-- never touched) and apply the next time nvim opens
if #vim.api.nvim_list_uis() > 0 then
  vim.defer_fn(function()
    M.check(function(count, repo)
      if count > 0 then
        M.apply(repo)
      end
    end)
  end, 3000)
end

return M
