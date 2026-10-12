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

The installer links the configs to this repo (existing ones are backed up as `*.bak-<date>`), and lists any missing tool with the command to install it. Running it again is safe.

| What | Linked to |
|---|---|
| `nvim/` | `~/.config/nvim` · Windows: `%LOCALAPPDATA%\nvim` |
| `wezterm/` | `~/.config/wezterm` |
| `windows-terminal/nvim-keys.json` | merged into Windows Terminal settings (Windows only) |

First launch of `nvim` installs the plugins. Then run `:Copilot auth` once to enable AI suggestions.

## Shortcuts

| Keys | Action |
|---|---|
| `Ctrl+P` | Find file |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+F` | Search in project |
| `Ctrl+Shift+O` | Open folder (project list) |
| `Ctrl+B` | File explorer |
| `Ctrl+W` / `Ctrl+Tab` | Close tab / next tab |
| `Ctrl+S` | Save |
| `Ctrl+/` | Toggle comment |
| `Ctrl+D` | Multi-cursor on next match |
| `Alt+↑/↓` | Move line |
| `Shift+Alt+F` | Format |
| `F2` / `F12` / `Shift+F12` | Rename / go to definition / references |
| `Ctrl+.` | Quick fix |
| `` Ctrl+` `` | Terminal |
| `Ctrl+Shift+G` | Git (lazygit) |
| `Ctrl+Shift+A` | Claude Code panel |
| `Ctrl+Alt+K` | Send selection or file to Claude |
| `Tab` | Accept Copilot suggestion |

On macOS inside WezTerm, `Cmd` works like in VS Code (`Cmd+P`, `Cmd+S`, `Cmd+Shift+P`, …).

## Why the terminal config matters

Terminals send `Ctrl+Shift+O` as `Ctrl+O`, so Neovim cannot tell them apart. WezTerm and Windows Terminal are set to send those keys as CSI-u sequences when needed. In WezTerm this only happens while `nvim` is the active program; elsewhere the keys keep their WezTerm behavior.

## Requirements

`nvim` ≥ 0.11, `git`, `rg`, `fd`, `lazygit`, `node`, a C compiler, `tree-sitter` CLI, and a Nerd Font. On Windows, WezTerm loads fonts from `wezterm/fonts/` (not versioned).
