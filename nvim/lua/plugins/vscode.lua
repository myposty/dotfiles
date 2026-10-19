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

  -- Long messages show as a popup in the corner, never as a panel at the bottom
  -- (VS Code has no such panel); the panel that :messages opens closes with q / Esc
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.presets = opts.presets or {}
      opts.presets.long_message_to_split = false
      opts.views = opts.views or {}
      opts.views.split = vim.tbl_deep_extend("force", opts.views.split or {}, {
        close = { keys = { "q", "<Esc>" } },
      })
    end,
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
      -- Images where the terminal speaks the kitty graphics protocol (WezTerm, kitty, ghostty)
      image = { enabled = true, doc = { enabled = true, inline = false, float = true } },
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
                desc = require("config.shortcuts").row(s.name, detail),
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
      -- Text boxes (new file, new folder, rename, save as...): one Esc cancels, like
      -- VS Code (Snacks' default first leaves typing and needs a second Esc)
      styles = {
        input = { keys = { i_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "i", expr = true } } },
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
            actions = {
              explorer_to_editor = function(picker)
                if picker.main and vim.api.nvim_win_is_valid(picker.main) then
                  vim.api.nvim_set_current_win(picker.main)
                else
                  vim.cmd("wincmd p")
                end
              end,
              -- r: rename only the name (and folders keep their open files)
              explorer_rename = function(picker, item)
                require("config.explorer").rename(picker, item)
              end,
              -- A: a new folder inside the selected one
              explorer_new_folder = function(picker)
                local base = picker:dir()
                Snacks.input({ prompt = "New folder" }, function(name)
                  if not name or vim.trim(name) == "" then
                    return
                  end
                  local path = vim.fs.normalize(base .. "/" .. vim.trim(name))
                  vim.fn.mkdir(path, "p")
                  local tree = require("snacks.explorer.tree")
                  tree:open(path)
                  tree:refresh(vim.fs.dirname(path))
                  require("snacks.explorer.actions").update(picker, { target = path })
                end)
              end,
            },
            -- Ctrl+B / Ctrl+Shift+E also close it when the tree itself has focus
            win = {
              list = {
                -- header with the project name and New File / New Folder / Refresh /
                -- Collapse buttons (lua/config/explorer.lua)
                wo = { winbar = "%{%v:lua.require'config.explorer'.winbar()%}" },
                keys = {
                  ["<c-b>"] = "close",
                  ["<c-s-e>"] = "close",
                  -- like VS Code's New File / New Folder buttons, inside the selected folder
                  -- (a: new file or folder/, r rename, d delete, c copy, m move)
                  ["<c-n>"] = "explorer_add",
                  ["A"] = "explorer_new_folder",
                  -- Esc goes back to the editor and leaves the explorer open (VS Code)
                  ["<esc>"] = "explorer_to_editor",
                },
              },
              input = { keys = { ["<c-b>"] = { "close", mode = { "n", "i" } }, ["<c-s-e>"] = { "close", mode = { "n", "i" } } } },
            },
          },
          -- an empty list still opens (a new machine has no recent files yet):
          -- the key always answers instead of doing nothing
          recent = { show_empty = true },
          projects = {
            show_empty = true,
            -- Only folders that exist on this machine (Windows, macOS or Linux);
            -- none of them on a new machine: look for projects under home
            dev = (function()
              local dirs = vim.tbl_filter(function(dir)
                return vim.fn.isdirectory(vim.fn.expand(dir)) == 1
              end, {
                "~/Desktop/proyect",
                "~/Desktop/proyect/Personal Proyect",
                "~/projects",
                "~/dev",
                "~/code",
              })
              return #dirs > 0 and dirs or { "~" }
            end)(),
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

  -- Changes since the last commit, like VS Code's diff view: a soft background on added
  -- and modified lines, deleted lines shown in place in soft red, and the exact words
  -- that changed a bit stronger
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, opts)
      opts.linehl = true
      opts.word_diff = true
      local function colors()
        local set = function(name, bg) vim.api.nvim_set_hl(0, name, { bg = bg }) end
        set("GitSignsAddLn", "#1f2d1c")
        set("GitSignsChangeLn", "#1c2636")
        set("GitSignsDeleteVirtLn", "#3a1f23")
        set("GitSignsTopdeleteLn", "#3a1f23")
        set("GitSignsChangedeleteLn", "#1c2636")
        set("GitSignsAddLnInline", "#33502b")
        set("GitSignsChangeLnInline", "#2c4466")
        set("GitSignsDeleteLnInline", "#5c262d")
        set("GitSignsDeleteVirtLnInline", "#5c262d")
      end
      colors()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })
    end,
  },

  -- Scrollbar on the right of every panel (code, Claude, the explorer), like VS Code:
  -- shows where you are, marks git changes, problems and search matches, and can be
  -- dragged with the mouse
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    opts = {
      current_only = false,
      winblend = 0,
      excluded_filetypes = { "snacks_dashboard", "snacks_input", "snacks_notif", "lazy", "mason" },
      handlers = {
        cursor = { enable = false },
        search = { enable = true },
        diagnostic = { enable = true },
        gitsigns = { enable = true },
        marks = { enable = false },
        quickfix = { enable = false },
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
        indicator = { style = "icon", icon = "▎" },
        -- X / middle click close like Ctrl+W (a diff as a whole, a side panel with its
        -- file); right click opens the tab menu instead of closing it by surprise
        close_command = function(n) require("config.tabs").close(n) end,
        middle_mouse_command = function(n) require("config.tabs").close(n) end,
        right_mouse_command = function(n) require("config.tabs").context(n) end,
      },
      -- The open file's tab stands out like VS Code's active tab: its own background,
      -- a blue bar and a bright name, also while the explorer or Claude has the focus;
      -- the other tabs stay dim. The background is explicit because the color theme
      -- is transparent (bufferline cannot shade it by itself).
      highlights = (function()
        local active_bg = "#2b2e33"
        local hl = { background = { fg = "#8b8b8b" } }
        for _, state in ipairs({ "selected", "visible" }) do
          for _, name in ipairs({ "close_button", "numbers", "diagnostic", "hint", "hint_diagnostic", "info",
            "info_diagnostic", "warning", "warning_diagnostic", "error", "error_diagnostic", "modified", "duplicate",
            "separator", "pick" }) do
            hl[name .. "_" .. state] = { bg = active_bg }
          end
          hl["buffer_" .. state] = { fg = "#ffffff", bg = active_bg, bold = true, italic = false }
          -- a file with problems shows its name in red / yellow, like VS Code
          for name, fg in pairs({ error = "#f48771", warning = "#cca700", info = "#ffffff", hint = "#ffffff" }) do
            hl[name .. "_" .. state] = { fg = fg, bg = active_bg, bold = true, italic = false }
            hl[name .. "_diagnostic_" .. state] = { fg = fg, bg = active_bg }
          end
          hl["indicator_" .. state] = { fg = "#0078d4", bg = active_bg }
        end
        return hl
      end)(),
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

  -- Clicking the branch in the status bar switches branch, like VS Code
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local b = opts.sections and opts.sections.lualine_b
      for i, c in ipairs(b or {}) do
        if c == "branch" or (type(c) == "table" and c[1] == "branch") then
          b[i] = vim.tbl_extend("force", type(c) == "table" and c or { "branch" }, {
            on_click = function() Snacks.picker.git_branches({ title = "Switch branch  (Ctrl+A new · Ctrl+X delete)" }) end,
          })
        end
      end
    end,
  },

  -- Framework language servers start only inside a project of that framework, like
  -- VS Code extensions that activate on a workspace: the Angular server started (and
  -- crashed) on every TypeScript file of any project, Tailwind on every web file.
  -- Plain language servers (TypeScript, PHP, Python...) already start only for their
  -- file types, and plugins load when first needed.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local function depends_on(pkg_dir, deps)
        local ok, pkg = pcall(function()
          return vim.json.decode(table.concat(vim.fn.readfile(pkg_dir .. "/package.json"), "\n"))
        end)
        if not ok or type(pkg) ~= "table" then
          return false
        end
        for _, field in ipairs({ "dependencies", "devDependencies", "peerDependencies" }) do
          for _, dep in ipairs(deps) do
            if type(pkg[field]) == "table" and pkg[field][dep] then
              return true
            end
          end
        end
        return false
      end
      local function only_in(markers, deps)
        return function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, markers)
          local pkg = not root and vim.fs.root(bufnr, "package.json")
          if pkg and depends_on(pkg, deps) then
            root = pkg
          end
          if root then
            on_dir(root)
          end
        end
      end
      local rules = {
        angularls = only_in({ "angular.json" }, { "@angular/core" }),
        tailwindcss = only_in({ "tailwind.config.js", "tailwind.config.cjs", "tailwind.config.mjs", "tailwind.config.ts" },
          { "tailwindcss", "@tailwindcss/vite", "@tailwindcss/postcss" }),
      }
      opts.servers = opts.servers or {}
      for name, root_dir in pairs(rules) do
        if opts.servers[name] ~= nil then
          opts.servers[name] = type(opts.servers[name]) == "table" and opts.servers[name] or {}
          opts.servers[name].root_dir = root_dir
        end
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
