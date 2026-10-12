-- Update check for the dotfiles repository. On start it fetches in the background
-- (never blocks) and, when GitHub has newer commits, asks to update. Works the
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

local function git(repo, args, cb)
  local cmd = { "git", "-C", repo }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(res)
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

-- Pulls the new commits (fast-forward only, never overwrites local edits) and
-- installs the plugin versions they pin
function M.apply(repo, done)
  repo = repo or M.repo()
  git(repo, { "pull", "--ff-only", "--quiet" }, function(res)
    if res.code ~= 0 then
      vim.notify("Could not update the dotfiles:\n" .. vim.trim(res.stderr or ""), vim.log.levels.ERROR, { title = "Dotfiles" })
    else
      pcall(function()
        require("lazy").restore({ show = false, wait = false })
      end)
      vim.notify("Dotfiles updated. Restart nvim to use the new version.", vim.log.levels.INFO, { title = "Dotfiles" })
    end
    if done then
      done(res.code == 0)
    end
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

-- Background check a few seconds after start (only with a screen, never in headless runs)
if #vim.api.nvim_list_uis() > 0 then
  vim.defer_fn(function()
    M.check(function(count, repo)
      if count > 0 then
        M.prompt(count, repo)
      end
    end)
  end, 3000)
end

return M
