return {
  -- Same theme as VS Code
  {
    "loctvl842/monokai-pro.nvim",
    priority = 1000,
    opts = { filter = "pro" },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "monokai-pro" } },

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
      picker = {
        sources = {
          explorer = { hidden = true, ignored = true, layout = { layout = { position = "left" } } },
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
          },
        },
      },
    },
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
