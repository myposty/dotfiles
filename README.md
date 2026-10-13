# dotfiles

Neovim (LazyVim with VS Code shortcuts) and WezTerm, for Windows, macOS and Linux.

## Install

```sh
git clone https://github.com/myposty/dotfiles.git ~/dotfiles
```

| System | Command |
|---|---|
| Windows | `powershell -ExecutionPolicy Bypass -File ~/dotfiles/install.ps1` |
| macOS / Linux | `bash ~/dotfiles/install.sh` (updates itself, asks once whether to use the system terminal or WezTerm (again with `--terminal`), installs Homebrew, zsh on macOS, sets the PATH in `~/.zshrc` / `~/.bashrc` and leaves you in a ready shell) |

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

**Updates:** a few seconds after nvim starts it checks GitHub in the background; when this repo has new commits it asks to update (fast-forward only, local edits are never overwritten). `:DotfilesUpdate` does it on demand. Works on Windows, macOS and Linux.

## Shortcuts

Press `F1` (or `:Shortcuts`) inside nvim for the full list: type to filter, `Enter` runs it. `Space` opens the menu with every LazyVim command. The start screen shows the main ones.

| Action | Windows | Linux | Mac |
|---|---|---|---|
| Find file | `Ctrl+P` | `Ctrl+P` | `Cmd+P` |
| Command palette | `Ctrl+Shift+P` | `Ctrl+Shift+P` | `Cmd+Shift+P` |
| Search in project | `Ctrl+Shift+F` | `Ctrl+Shift+F` | `Cmd+Shift+F` |
| Open folder (project list) | `Ctrl+Shift+O` | `Ctrl+Shift+O` | `Cmd+Shift+O` |
| Open folder by name (type to search) | `Ctrl+Shift+K` | `Ctrl+Shift+K` | `Cmd+Shift+K` |
| File explorer | `Ctrl+B` | `Ctrl+B` | `Cmd+B` |
| Close file / next tab | `Ctrl+W` / `Ctrl+Tab` | `Ctrl+W` / `Ctrl+Tab` | `Cmd+W` / `Cmd+Shift+]` |
| Save (formats with Prettier) | `Ctrl+S` | `Ctrl+S` | `Cmd+S` |
| Undo / redo | `Ctrl+Z` / `Ctrl+Shift+Z` | `Ctrl+Z` / `Ctrl+Shift+Z` | `Cmd+Z` / `Cmd+Shift+Z` |
| Select all | `Ctrl+A` | `Ctrl+A` | `Cmd+A` |
| Toggle comment | `Ctrl+/` | `Ctrl+/` | `Cmd+/` |
| Multi-cursor on next match | `Ctrl+D` | `Ctrl+D` | `Cmd+D` |
| Move line | `Alt+Up/Down` | `Alt+Up/Down` | `Option+Up/Down` |
| Format document | `Shift+Alt+F` | `Shift+Alt+F` | `Shift+Option+F` |
| Rename / go to definition / references | `F2` / `F12` / `Shift+F12` | `F2` / `F12` / `Shift+F12` | `F2` / `F12` / `Shift+F12` |
| Quick fix | `Ctrl+.` | `Ctrl+.` | `Cmd+.` |
| Terminal show-hide / new terminal | `Ctrl+J` / `` Ctrl+Shift+` `` | `Ctrl+J` / `` Ctrl+Shift+` `` | `Cmd+J` / `` Cmd+Shift+` `` |
| Terminal show-hide (alternative) | `` Ctrl+` `` | `` Ctrl+` `` | `` Ctrl+` `` |
| Go to editor 1/2/3 / file explorer | `Ctrl+1/2/3` / `Ctrl+0` | `Ctrl+1/2/3` / `Ctrl+0` | `Cmd+1/2/3` / `Cmd+0` |
| Split editor | `Ctrl+\` | `Ctrl+\` | `Cmd+\` |
| Go to line | `Ctrl+G` | `Ctrl+G` | `Cmd+G` |
| Replace in file / in project | `Ctrl+H` / `Ctrl+Shift+H` | `Ctrl+H` / `Ctrl+Shift+H` | `Cmd+Option+F` / `Cmd+Shift+H` |
| Select line / all occurrences | `Ctrl+L` / `Ctrl+Shift+L` | `Ctrl+L` / `Ctrl+Shift+L` | `Cmd+L` / `Cmd+Shift+L` |
| New line below / above | `Ctrl+Enter` / `Ctrl+Shift+Enter` | `Ctrl+Enter` / `Ctrl+Shift+Enter` | `Cmd+Enter` / `Cmd+Shift+Enter` |
| Markdown: preview / edit (or click Preview) | `Ctrl+Shift+V` / `Ctrl+K V` | `Ctrl+Shift+V` / `Ctrl+K V` | `Cmd+Shift+V` / `Cmd+K V` |
| Toggle word wrap | `Alt+Z` | `Alt+Z` | `Option+Z` |
| Next / previous match | `F3` / `Shift+F3` | `F3` / `Shift+F3` | `F3` / `Shift+F3` |
| Settings | `Ctrl+,` | `Ctrl+,` | `Cmd+,` |
| Resize panel (or drag the border) | `Ctrl+Arrows` | `Ctrl+Arrows` | `Ctrl+Arrows` |
| Git (lazygit) | `Ctrl+Shift+G` | `Ctrl+Shift+G` | `Cmd+Shift+G` |
| Claude Code panel | `Ctrl+Shift+A` | `Ctrl+Shift+A` | `Cmd+Shift+A` |
| Send selection or file to Claude | `Ctrl+Alt+K` | `Ctrl+Alt+K` | `Cmd+Option+K` |
| Start / end of line | `Home` / `End` | `Home` / `End` | `Cmd+Left` / `Cmd+Right` |
| Previous / next word | `Alt+Left` / `Alt+Right` | `Alt+Left` / `Alt+Right` | `Option+Left` / `Option+Right` |
| Delete the previous word | `Alt+Backspace` | `Alt+Backspace` | `Option+Backspace` |
| Accept Copilot suggestion | `Tab` | `Tab` | `Tab` |
| All shortcuts (type to filter) | `F1` | `F1` | `F1` |

Everywhere: click a file path in Claude or a terminal to open it (a numbered diff line opens at that line); `Space` opens every LazyVim command; with the explorer open, the Git changes panel sits under the file tree (`s` stage, `c` commit, `p` push, `P` pull).

**Mac.** The Mac column works in WezTerm. macOS Terminal.app keeps every `Cmd` key for itself, so there use the Windows / Linux keys (`Ctrl+Shift+A` opens Claude, `Ctrl+K V` the markdown preview).

**Windows.** In Windows Terminal, outside nvim, paste with `Ctrl+V`: `Ctrl+Shift+V` goes to nvim (markdown preview).

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
