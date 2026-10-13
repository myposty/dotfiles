-- Start screen layout: the panel height is a row budget shared out by priority, so
-- the content always fits and there is nothing to scroll. Re-computed on every redraw
-- (Snacks redraws on resize), from the most to the least important part.
local ROWS = { folder = 2, name = 2, logo = 8, startup = 1, git_min = 4 }
-- When even the shortcuts do not fit, these go first (F1 still lists everything)
local DROP_FIRST = { "n", "l", "k", "r", ",", "s", "p", "e", "g", "c", "f", "o" }

local function start_screen_layout(self)
  local rows = self._size and self._size.height or vim.o.lines
  local keys = require("config.shortcuts").dashboard_keys()
  local layout = { keys = keys }
  local free = rows - (#keys + 1) - 1 -- shortcuts + bottom padding, and Snacks' last line
  for _, drop in ipairs(DROP_FIRST) do
    if free >= 0 then
      break
    end
    for i, k in ipairs(keys) do
      if k.key == drop then
        table.remove(keys, i)
        free = free + 1
        break
      end
    end
  end
  for _, part in ipairs({ "folder", "name", "logo", "startup" }) do
    if free >= ROWS[part] then
      layout[part] = true
      free = free - ROWS[part]
    end
  end
  if layout.logo then
    free = free + ROWS.name -- the big logo replaces the one-line name
  end
  -- Recent sessions come before git: title + one row per session + padding, 1 to 5
  -- sessions as space allows (skipped under 3 free rows)
  layout.sessions = 0
  if free >= 3 then
    local list = require("config.sessions").list(5)
    layout.session_items = list
    layout.sessions = math.min(#list, 5, free - 2)
    if layout.sessions > 0 then
      free = free - (layout.sessions + 2)
    end
  end
  layout.git_rows = free
  return layout
end

-- Plugins that draw icons read this: false when the terminal font has no Nerd glyphs
if not require("config.shortcuts").nerd_font() then
  vim.g.have_nerd_font = false
end

-- Always dark, whatever the terminal or the system theme. Neovim asks the terminal
-- for its background and switches to "light" on a light one: switch it right back.
vim.o.background = "dark"
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function()
    if vim.o.background ~= "dark" then
      vim.schedule(function()
        vim.o.background = "dark"
        if vim.g.colors_name ~= "monokai_soda" then
          LazyVim.config.colorscheme()
        end
      end)
    end
  end,
})

-- macOS Terminal.app before 24-bit color support: Neovim would send colors it cannot
-- show. There the theme runs on the 256-color palette, each color mapped to the
-- nearest one, so it looks like Monokai Soda too.
local function only_256_colors()
  -- COLORTERM=truecolor can be set there anyway (shell setups), so it is not trusted
  return vim.env.NVIM_FORCE_256 == "1" or vim.env.TERM_PROGRAM == "Apple_Terminal"
end

-- Nearest xterm-256 color: the 6x6x6 cube or the 24-step gray ramp
local function to_256(rgb)
  local r, g, b = bit.rshift(rgb, 16), bit.band(bit.rshift(rgb, 8), 255), bit.band(rgb, 255)
  local levels = { 0, 95, 135, 175, 215, 255 }
  local function level(v)
    local best = 1
    for i, l in ipairs(levels) do
      if math.abs(v - l) < math.abs(v - levels[best]) then
        best = i
      end
    end
    return best - 1
  end
  local ri, gi, bi = level(r), level(g), level(b)
  local cube = { levels[ri + 1], levels[gi + 1], levels[bi + 1] }
  local gray = math.max(0, math.min(23, math.floor(((r + g + b) / 3 - 8) / 10 + 0.5)))
  local gv = 8 + gray * 10
  local dist = function(x, y, z) return (r - x) ^ 2 + (g - y) ^ 2 + (b - z) ^ 2 end
  if dist(gv, gv, gv) < dist(cube[1], cube[2], cube[3]) then
    return 232 + gray
  end
  return 16 + 36 * ri + 6 * gi + bi
end

local function use_256_colors()
  vim.o.termguicolors = false
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    if not hl.link and (hl.fg or hl.bg or hl.sp) then
      hl.ctermfg = hl.fg and to_256(hl.fg) or nil
      hl.ctermbg = hl.bg and to_256(hl.bg) or nil
      hl.cterm = { bold = hl.bold, italic = hl.italic, underline = hl.underline, undercurl = hl.undercurl,
        reverse = hl.reverse, strikethrough = hl.strikethrough }
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

if only_256_colors() then
  -- every color any plugin defines from now on gets its 256-color twin right away
  -- (the tabs bar, for one, redefines its colors on every redraw)
  local set_hl = vim.api.nvim_set_hl
  local function as_number(c)
    if type(c) == "number" then
      return c
    elseif type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
      return tonumber(c:sub(2), 16)
    end
  end
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim_set_hl = function(ns, name, val)
    if type(val) == "table" and not val.link then
      local fg, bg = as_number(val.fg), as_number(val.bg)
      if fg and val.ctermfg == nil then
        val.ctermfg = to_256(fg)
      end
      if bg and val.ctermbg == nil then
        val.ctermbg = to_256(bg)
      end
    end
    return set_hl(ns, name, val)
  end
  -- plugins that load later bring their own colors: convert again after each one
  vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
    callback = function() vim.schedule(use_256_colors) end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyLoad", "VeryLazy" },
    callback = function()
      vim.schedule(use_256_colors)
      -- some (the tabs bar) set their colors a moment after loading
      vim.defer_fn(use_256_colors, 500)
    end,
  })
end

-- See-through background only in the terminals this setup makes dark: WezTerm (dark
-- with blur) and Windows Terminal (Monokai Soda). In any other terminal, light ones
-- included, the theme paints its own dark background.
local function see_through()
  return vim.env.TERM_PROGRAM == "WezTerm" or vim.env.WEZTERM_PANE ~= nil or vim.env.WT_SESSION ~= nil
end

return {
  -- Monokai Soda (same palette as the terminal) with a transparent background,
  -- so the terminal background (opacity / blur) shows through
  {
    "tanvirtin/monokai.nvim",
    priority = 1000,
    config = function()
      local monokai = require("monokai")
      monokai.setup({ palette = monokai.soda, italics = false })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        vim.o.background = "dark"
        vim.cmd.colorscheme("monokai_soda")
        if not see_through() then
          return
        end
        local clear = {
          "Normal", "NormalNC", "NormalFloat", "SignColumn", "LineNr", "CursorLineNr", "EndOfBuffer",
          "FoldColumn", "StatusLine", "StatusLineNC", "TabLine", "TabLineFill", "WinBar", "WinBarNC",
          "SnacksDashboardNormal", "SnacksPickerList", "SnacksPickerInput", "SnacksPickerPreview",
        }
        for _, group in ipairs(clear) do
          local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
          hl.bg = nil
          vim.api.nvim_set_hl(0, group, hl)
        end
      end,
    },
  },

  -- Ctrl+D multi-cursor, like VS Code
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "VeryLazy",
    init = function()
      vim.g.VM_maps = {
        ["Find Under"] = "<C-d>",
        ["Find Subword Under"] = "<C-d>",
        ["Add Cursor Down"] = "<C-A-Down>",
        ["Add Cursor Up"] = "<C-A-Up>",
      }
    end,
  },

  -- Explorer on the left, showing hidden and ignored files like VS Code.
  -- "Open folder" lists every project under the proyect directories.
  {
    "folke/snacks.nvim",
    opts = {
      -- Start screen: the user's name as logo (lua/config/logo.lua) and VS Code shortcuts (lua/config/shortcuts.lua)
      dashboard = {
        preset = {
          keys = require("config.shortcuts").dashboard_keys(),
        },
        width = 48,
        -- Responsive: everything fits the panel height (see start_screen_layout).
        -- Tall panel: big logo + folder + shortcuts + git + startup time. As it gets
        -- shorter, the git files, startup time, logo, name and folder go away in that
        -- order, and on a tiny panel the least used shortcuts too.
        sections = {
          function(self)
            self._layout = start_screen_layout(self)
            if not self._layout.name then
              return {}
            end
            local width = self._size and self._size.width or vim.o.columns
            local compact = not self._layout.logo
            return { header = require("config.logo").header(width, compact), padding = compact and 1 or 2 }
          end,
          -- Current folder, like the VS Code window title
          function(self)
            if not self._layout.folder then
              return {}
            end
            return { text = { { vim.fn.fnamemodify(vim.fn.getcwd(), ":~"), hl = "SnacksDashboardDesc" } }, align = "center", padding = 1 }
          end,
          function(self)
            return vim.list_extend({ gap = 0, padding = 1 }, self._layout.keys)
          end,
          -- Recent sessions (lua/config/sessions.lua): 1 = the last one
          function(self)
            local count = self._layout.sessions or 0
            if count < 1 then
              return {}
            end
            local icon = require("config.shortcuts").nerd_font() and "\u{f017} " or "↺ "
            local items = { { title = "Recent sessions  (1 = last, :Sessions = all)", padding = 1 } }
            for i = 1, count do
              local s = self._layout.session_items[i]
              -- like the shortcut rows: name, then in the keys column the git branch
              -- or, without one, the folder it lives in (its end, the part that tells)
              local home = vim.fs.normalize(s.dir) == vim.fs.normalize(vim.uv.os_homedir())
              local detail = s.branch and ("⎇ " .. s.branch)
                or (home and "home folder" or vim.fn.fnamemodify(s.dir, ":~:h"))
              if vim.fn.strchars(detail) > 22 then
                detail = ".." .. vim.fn.strcharpart(detail, vim.fn.strchars(detail) - 20)
              end
              items[#items + 1] = {
                icon = icon,
                key = tostring(i),
                desc = ("%-20s %s"):format(vim.fn.strcharpart(s.name, 0, 20), detail),
                action = function() require("config.sessions").open(s) end,
              }
            end
            items[#items].padding = 1
            return items
          end,
          -- Git: branch and changed files, read fresh on every redraw (plain text,
          -- no embedded terminal). Only inside a repository.
          function(self)
            local lines = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "status", "--short", "--branch" })
            if vim.v.shell_error ~= 0 or #lines == 0 then
              return {}
            end
            local free = self._layout.git_rows
            -- title + gap + summary + bottom gap = 4 rows, then one row per file
            if free < ROWS.git_min then
              return {}
            end
            local head = lines[1]:gsub("^## ", "")
            local branch = head:match("^No commits yet on (%S+)") or head:match("^([^%s%.]+)") or head
            local ahead, behind = head:match("ahead (%d+)"), head:match("behind (%d+)")
            local changed = #lines - 1
            local summary = branch .. "  ·  " .. (changed == 0 and "clean" or (changed .. " changed"))
              .. (ahead and ("  ·  " .. ahead .. " to push") or "")
              .. (behind and ("  ·  " .. behind .. " to pull") or "")
            local items = {
              { title = "Git  (" .. require("config.shortcuts").entry_label({ keys = "Ctrl+Shift+G", alt = "Alt+G" })
                .. ": commit, push, merge)", padding = 1 },
              { text = { { summary, hl = "SnacksDashboardKey" } }, align = "center" },
            }
            local room = free - 4
            for i = 2, math.min(#lines, room + 1) do
              local file = lines[i]
              if i == room + 1 and #lines > room + 1 then
                file = ("  … %d more"):format(#lines - room)
              end
              items[#items + 1] = { text = { { file:sub(1, 44), hl = "SnacksDashboardDesc" } } }
            end
            items[#items].padding = 1
            return items
          end,
          function(self)
            return self._layout.startup and { section = "startup" } or {}
          end,
        },
      },
      -- Ctrl+J toggles the terminal like VS Code (see keymaps.lua), so the terminal
      -- must not keep Snacks' own Ctrl+J "go to the window below"
      terminal = { win = { keys = { nav_j = false } } },
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            layout = { layout = { position = "left" } },
            -- Ctrl+B / Ctrl+Shift+E also close it when the tree itself has focus
            win = {
              list = { keys = { ["<c-b>"] = "close", ["<c-s-e>"] = "close" } },
              input = { keys = { ["<c-b>"] = { "close", mode = { "n", "i" } }, ["<c-s-e>"] = { "close", mode = { "n", "i" } } } },
            },
          },
          projects = {
            -- Only folders that exist on this machine (Windows, macOS or Linux)
            dev = vim.tbl_filter(function(dir)
              return vim.fn.isdirectory(vim.fn.expand(dir)) == 1
            end, {
              "~/Desktop/proyect",
              "~/Desktop/proyect/Personal Proyect",
              "~/projects",
              "~/dev",
              "~/code",
            }),
            max_depth = 3,
            -- Choosing a project opens it like a folder (see lua/config/folders.lua)
            confirm = function(picker, item)
              picker:close()
              if item then
                vim.schedule(function()
                  require("config.folders").use(item.file)
                end)
              end
            end,
          },
        },
      },
    },
  },

  -- Tabs like VS Code: always visible, each with an X to close it (click it or Ctrl+W)
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        always_show_bufferline = true,
        show_buffer_close_icons = true,
        show_close_icon = false,
      },
    },
  },

  -- Every folder icon in the same blue as macOS folders (named folders like .git or
  -- .github keep their own glyph, only the color changes)
  {
    "nvim-mini/mini.icons",
    config = function(_, opts)
      vim.api.nvim_set_hl(0, "FolderIcon", { fg = "#4AA8F5", default = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function() vim.api.nvim_set_hl(0, "FolderIcon", { fg = "#4AA8F5", default = true }) end,
      })
      -- no Nerd Font in the terminal: plain ASCII icons instead of "?" boxes
      if not require("config.shortcuts").nerd_font() then
        opts.style = "ascii"
      end
      local icons = require("mini.icons")
      icons.setup(opts)
      opts.default = vim.tbl_deep_extend("force", opts.default or {}, { directory = { hl = "FolderIcon" } })
      opts.directory = opts.directory or {}
      for _, name in ipairs(icons.list("directory")) do
        opts.directory[name] = vim.tbl_extend("force", opts.directory[name] or {}, { hl = "FolderIcon" })
      end
      icons.setup(opts)
    end,
  },

  -- Markdown preview inside the editor (headings, tables, lists, code), toggled with
  -- Ctrl+Shift+V / Ctrl+K V like VS Code. Files open as plain text for editing.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    -- anti_conceal off: the preview is read-only, the cursor line renders like the rest
    opts = { enabled = false, file_types = { "markdown" }, anti_conceal = { enabled = false } },
  },

  -- Ctrl+Y is redo (as in VS Code on Windows): the completion menu keeps it to accept
  -- a suggestion only while it is open, otherwise it redoes
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}
      opts.keymap["<C-y>"] = {
        "select_and_accept",
        function()
          vim.schedule(function() vim.cmd("redo") end)
          return true
        end,
      }
    end,
  },

  -- php-cs-fixer and phpcs need a local PHP; skip them when PHP is not installed
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      if vim.fn.executable("php") == 0 then
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        opts.formatters_by_ft.php = {}
      end
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      if vim.fn.executable("php") == 0 then
        opts.linters_by_ft = opts.linters_by_ft or {}
        opts.linters_by_ft.php = {}
      end
    end,
  },

  -- The extra runs ":Copilot auth" as a build step before the command exists; sign in manually instead
  { "zbirenbaum/copilot.lua", build = function() end },

  -- Claude Code in a right-side panel, with diffs shown inside Neovim (like the VS Code extension)
  {
    "coder/claudecode.nvim",
    opts = {
      terminal = { split_side = "right", split_width_percentage = 0.38 },
    },
    keys = {
      { "<C-S-a>", "<cmd>ClaudeCodeFocus<cr>", mode = { "n", "i", "t" }, desc = "Claude Code" },
      { "<C-A-k>", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<C-A-k>", "<cmd>ClaudeCodeAdd %<cr>", mode = { "n", "i" }, desc = "Send file to Claude" },
    },
  },
}
