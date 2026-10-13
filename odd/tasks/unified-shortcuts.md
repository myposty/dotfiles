# Unified shortcuts and icons on every system

## Objective
Every shortcut works on Windows, Linux and macOS, in any terminal, without clashing with
macOS system shortcuts; the start screen shows keys that really work in the current
terminal; icons render everywhere (no `?` boxes on macOS).

## Problem
- VS Code keys with `Ctrl+Shift` / `Cmd` only reach nvim in terminals that forward them
  (WezTerm, Windows Terminal with our bindings). macOS Terminal.app keeps every `Cmd` key
  and sends `Ctrl+Shift+X` as `Ctrl+X`, so e.g. `Ctrl+Shift+A` (Claude) selected all.
- Some macOS keys belong to the system (e.g. `Ctrl+Arrows` = Spaces / Mission Control).
- The start screen shows keys that do not work in the terminal in use (confusing).
- Nerd Font icons show as `?` when the terminal font is not a Nerd Font (Terminal.app
  when WezTerm was chosen in the installer).

## Design
- Two keys per action:
  - the VS Code key (`Ctrl+Shift+X` on Windows/Linux, `Cmd+...` on macOS), where the
    terminal forwards it;
  - a universal key that reaches nvim in every terminal: plain `Ctrl+letter` when free,
    otherwise `Alt+letter` (`Option+letter` on macOS, Option as Meta).
- Labels (start screen, F1) show the key that works in the current terminal.
- No action on keys macOS reserves.
- Icons: Nerd Font where present; plain Unicode symbols (rendered by system fonts)
  where not. The installer sets the Nerd Font in Terminal.app whatever the terminal choice.

## Scope (authorized)
`nvim/lua/config/{keymaps,shortcuts,autocmds}.lua`, `nvim/lua/plugins/vscode.lua`,
`wezterm/wezterm.lua`, `windows-terminal/nvim-keys.json`, `install.sh`, `install.ps1`,
`README.md`.

## Tasks
- [x] T1 Research: macOS system / Terminal.app / WezTerm / GNOME / Konsole / Windows
      Terminal shortcut conflicts (sourced).
- [x] T2 Key map: universal key per action, drop conflicts, Ctrl+A back to select all.
- [x] T3 Labels: start screen and F1 show the key that works in the current terminal.
- [x] T4 Icons: Unicode fallback when no Nerd Font; installer always sets the Terminal.app font.
- [x] T5 README table and verification on simulated terminals (Windows Terminal, WezTerm,
      Terminal.app, GNOME-like).

## Checks
- pty tests sending the exact bytes each terminal sends, per action.
- Screen capture (pyte) of the start screen per terminal.
- `wezterm show-keys` (normal and WEZTERM_FORCE_MAC), `bash -n install.sh`, F1 check.

## TDD
Off (config repo, no test runner); functional pty checks instead.

## Progress
- T1 done: research (Apple support 102650, Terminal.app guide, WezTerm default keys, Windows Terminal actions).
  Cmd never reaches programs in Terminal.app; Ctrl+Shift+X arrives as Ctrl+X there and in GNOME/Konsole.
- T2-T4 done (delegated writer; route: delegated direct, 6 files). Universal Alt keys, Ctrl+Y redo
  (blink.cmp keeps Ctrl+Y only while its menu is open), Ctrl+A select all everywhere, labels per
  terminal, Unicode icons without a Nerd Font, Terminal.app always set up, Linux Nerd Font install.
- T5 done: README "Any terminal" column.

## Verification evidence
- Start screen per terminal (pyte capture): Windows Terminal Ctrl+Shift keys; WezTerm on Mac Cmd keys;
  Terminal.app Option keys + Unicode icons; GNOME-like Alt keys.
- Universal keys in Terminal.app and GNOME-like: Alt+P palette, Alt+K folder search, Alt+F grep,
  Alt+R recent, Alt+C Claude, Alt+E explorer all open; Ctrl+A select all; Ctrl+Y redo.
- Regression: markdown preview keys ok, Claude links 16/16, F1 62 items, wezterm show-keys
  (normal and Mac) no errors, install.sh syntax ok.
- Not run here: real macOS / Linux machines (Terminal.app font detection, Linux font install).

## Follow-up: sessions and launch after install (accepted 2026-10-13)
- [x] T6 Start screen lists recent sessions (persistence.nvim), keys 1-5, 1 = last; :Sessions lists all;
      temp folders filtered; branch shown as "⎇ feat/x"; fits the row budget. (delegated writer)
- [x] T7 install.sh / install.ps1 open nvim when done (DOTFILES_NO_LAUNCH=1 skips); nvim keeps the
      update restart loop. (delegated writer)
- Evidence: start screen shows 5 sessions; pressing 1 restored joajuproject with its 6 files;
  24-row window hides the section and fits (21/22); install.ps1 in an interactive console opened
  nvim after 15 s and ended cleanly after :qa; F1 63 items; universal keys still pass; install.sh syntax ok.
