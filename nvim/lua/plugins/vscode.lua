-- Start screen rows: folder line + padding, one row per shortcut + padding, startup line
local START_FIXED_ROWS = 2 + #require("config.shortcuts").dashboard_keys() + 1 + 1
-- Big logo: 6 rows of letters + 2 rows of padding
local LOGO_ROWS = 8

local function start_screen_rows(self)
  return self._size and self._size.height or vim.o.lines
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
        vim.cmd.colorscheme("monokai_soda")
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
        -- Everything fits the panel height, never scrolls. Re-drawn on every resize:
        -- the git status gets only the rows left over (hidden if none), and on a
        -- short panel the big logo becomes a one-line name.
        sections = {
          function(self)
            local width = self._size and self._size.width or vim.o.columns
            local compact = start_screen_rows(self) < START_FIXED_ROWS + LOGO_ROWS
            return { header = require("config.logo").header(width, compact), padding = compact and 1 or 2 }
          end,
          -- Current folder, like the VS Code window title
          function()
            return { text = { { vim.fn.fnamemodify(vim.fn.getcwd(), ":~"), hl = "SnacksDashboardDesc" } }, align = "center", padding = 1 }
          end,
          { section = "keys", gap = 0, padding = 1 },
          -- Git: branch and changed files, read fresh on every redraw (plain text,
          -- no embedded terminal). Only inside a repository.
          function(self)
            local lines = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "status", "--short", "--branch" })
            if vim.v.shell_error ~= 0 or #lines == 0 then
              return {}
            end
            local rows = start_screen_rows(self)
            local logo = rows < START_FIXED_ROWS + LOGO_ROWS and 2 or LOGO_ROWS
            local free = rows - START_FIXED_ROWS - logo - 2 -- keep one spare row
            -- title + gap + summary + bottom gap = 4 rows, then one row per file
            if free < 4 then
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
              { title = "Git  (Ctrl+Shift+G: commit, push, merge)", padding = 1 },
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
          { section = "startup" },
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
