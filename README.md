# dotfiles

Neovim (LazyVim with VS Code shortcuts) and WezTerm, for Windows, macOS and Linux.

## Install

```sh
git clone https://github.com/myposty/dotfiles.git ~/dotfiles
```

| System | Command |
|---|---|
| Windows | `powershell -ExecutionPolicy Bypass -File ~/dotfiles/install.ps1` |
| macOS / Linux | `bash ~/dotfiles/install.sh` |

The installer:

1. Installs missing tools (winget on Windows, Homebrew on macOS, apt/dnf/pacman on Linux; Neovim and lazygit from their official releases on Linux).
2. Links the configs to this repo (existing ones are backed up as `*.bak-<date>`).
3. Pre-installs every plugin, language server and treesitter parser, and fails loudly if any of them did not install.

Running it again is safe. Tested on Windows 11 and a clean Debian 12.

| What | Linked to |
|---|---|
| `nvim/` | `~/.config/nvim` · Windows: `%LOCALAPPDATA%\nvim` |
| `wezterm/` | `~/.config/wezterm` |
| `windows-terminal/nvim-keys.json` | merged into Windows Terminal settings (Windows only) |

Run `:Copilot auth` once inside `nvim` to enable AI suggestions.

## Shortcuts

Press `F1` (or `:Shortcuts`) inside nvim for the full list: type to filter, `Enter` runs it. `Space` opens the menu with every LazyVim command. The start screen shows the main ones.

| Keys | Action |
|---|---|
| `Ctrl+P` | Find file |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+F` | Search in project |
| `Ctrl+Shift+O` | Open folder (project list) |
| `Ctrl+Shift+K` | Browse folders (`Enter` goes in, `..` goes up) |
| `Ctrl+B` | File explorer |
| `Ctrl+W` or the tab's X / `Ctrl+Tab` | Close file / next tab |
| `Ctrl+S` | Save (formats with Prettier) |
| `Ctrl+/` | Toggle comment |
| `Ctrl+D` | Multi-cursor on next match |
| `Alt+↑/↓` | Move line |
| `Shift+Alt+F` | Format |
| `F2` / `F12` / `Shift+F12` | Rename / go to definition / references |
| `Ctrl+.` | Quick fix |
| `` Ctrl+` `` | Terminal (show / hide) |
| `Ctrl+H/J/K/L` | Go to the panel left / down / up / right |
| `Ctrl+Arrows` | Resize panel (or drag the border) |
| `Space w H/J/K/L` | Move panel left / down / up / right |
| `Ctrl+Shift+G` | Git (lazygit) |
| `Ctrl+Shift+A` | Claude Code panel |
| `Ctrl+Alt+K` | Send selection or file to Claude |
| `Tab` | Accept Copilot suggestion |

On macOS inside WezTerm, `Cmd` works like in VS Code (`Cmd+P`, `Cmd+S`, `Cmd+Shift+P`, …).

## Editing like VS Code

Files open ready to type: letters write text. `Esc` switches to Vim's command mode (letters run commands) and `i` goes back to typing. Saving, completion, auto-closing tags and brackets, and format on save (Prettier) work per language: TypeScript, Vue, Astro, Tailwind, PHP, Python, C/C++, Docker, YAML, TOML, Prisma and JSON.

## Customize

| What | File |
|---|---|
| Name on the start screen | Asked on the first start; change it with `:SetName` or `n` on the start screen. Stored per machine, not in this repo |
| Logo letters | `nvim/lua/config/logo.lua` |
| Shortcut list and start screen entries | `nvim/lua/config/shortcuts.lua` |
| Key bindings | `nvim/lua/config/keymaps.lua` |

## Why the terminal config matters

Terminals send `Ctrl+Shift+O` as `Ctrl+O`, so Neovim cannot tell them apart. WezTerm and Windows Terminal are set to send those keys as CSI-u sequences when needed. In WezTerm this only happens while `nvim` is the active program; elsewhere the keys keep their WezTerm behavior.

## Requirements

Installed automatically: `nvim` ≥ 0.11, `git`, `rg`, `fd`, `lazygit`, `node`, `python3`, a C compiler and the `tree-sitter` CLI. macOS needs Homebrew first. On Windows, WezTerm loads fonts from `wezterm/fonts/` (not versioned); copy a Nerd Font there.
