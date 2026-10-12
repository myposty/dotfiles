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
        width = 44,
        sections = {
          -- Re-drawn on every resize with the width of the start screen panel
          function(self)
            local width = self._size and self._size.width or vim.o.columns
            return { header = require("config.logo").header(width), padding = 2 }
          end,
          -- Current folder, like the VS Code window title
          function()
            return { text = { { vim.fn.fnamemodify(vim.fn.getcwd(), ":~"), hl = "SnacksDashboardDesc" } }, align = "center", padding = 1 }
          end,
          { section = "keys", gap = 1, padding = 1 },
          -- Git: branch and changed files, only inside a repository
          function()
            if not Snacks.git.get_root() then
              return {}
            end
            return {
              { title = "Git  (Ctrl+Shift+G to commit, push, merge)", padding = 1 },
              {
                section = "terminal",
                cmd = "git status --short --branch --renames",
                height = 8,
                padding = 1,
                indent = 2,
                ttl = 0,
              },
            }
          end,
          { section = "startup" },
        },
      },
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
      { "<C-S-a>", "<cmd>ClaudeCodeFocus<cr>", mode = { "n", "t" }, desc = "Claude Code" },
      { "<C-A-k>", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<C-A-k>", "<cmd>ClaudeCodeAdd %<cr>", mode = "n", desc = "Send file to Claude" },
    },
  },
}
