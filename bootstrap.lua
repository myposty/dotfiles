-- Headless first-time setup for the nvim config. Installs everything up front
-- and waits for it: plugins, Mason tools, language servers, treesitter parsers.
-- Usage: nvim --headless -c "luafile bootstrap.lua"
-- Exits with code 1 and a list of what failed, 0 when everything is installed.

local failed = {}
local function say(msg)
  io.stdout:write(msg .. "\n")
end

local function finish()
  if #failed > 0 then
    say("FAILED: " .. table.concat(failed, ", "))
    vim.cmd("cquit 1")
  else
    say("OK: everything installed")
    vim.cmd("qall!")
  end
end

local ok, err = pcall(function()
  -- 1. Plugins
  say("[1/4] plugins")
  require("lazy").sync({ wait = true, show = false })
  for _, p in pairs(require("lazy.core.config").plugins) do
    if not p._.installed then
      table.insert(failed, "plugin " .. p.name)
    end
  end
  vim.api.nvim_exec_autocmds("UIEnter", {})
  require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig", "nvim-treesitter" } })

  -- 2. Mason tools and language servers
  say("[2/4] mason registry")
  local mr = require("mason-registry")
  local refreshed = false
  mr.refresh(function()
    refreshed = true
  end)
  vim.wait(120000, function()
    return refreshed
  end, 200)

  local expected = vim.deepcopy(LazyVim.opts("mason.nvim").ensure_installed or {})
  local to_package = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
  for name, server in pairs(LazyVim.opts("nvim-lspconfig").servers or {}) do
    local enabled = server == true or (type(server) == "table" and server.enabled ~= false and server.mason ~= false)
    if enabled and to_package[name] then
      table.insert(expected, to_package[name])
    end
  end
  expected = vim.fn.uniq(vim.fn.sort(expected))

  say("[3/4] mason packages: " .. table.concat(expected, ", "))
  for _, name in ipairs(expected) do
    local has, pkg = pcall(mr.get_package, name)
    if has and not pkg:is_installed() and not pkg:is_installing() then
      pkg:install()
    elseif not has then
      table.insert(failed, "mason " .. name .. " (unknown package)")
    end
  end
  vim.wait(1200000, function()
    for _, name in ipairs(expected) do
      local has, pkg = pcall(mr.get_package, name)
      if has and pkg:is_installing() then
        return false
      end
    end
    return true
  end, 500)
  for _, name in ipairs(expected) do
    local has, pkg = pcall(mr.get_package, name)
    if has and not pkg:is_installed() then
      table.insert(failed, "mason " .. name)
    end
  end

  -- 3. Treesitter parsers
  local parsers = LazyVim.opts("nvim-treesitter").ensure_installed or {}
  say("[4/4] treesitter parsers: " .. #parsers)
  require("nvim-treesitter").install(parsers):wait(1200000)
  for _, lang in ipairs(parsers) do
    if not pcall(vim.treesitter.language.add, lang) then
      table.insert(failed, "parser " .. lang)
    end
  end
end)

if not ok then
  table.insert(failed, "bootstrap error: " .. tostring(err))
end
finish()
