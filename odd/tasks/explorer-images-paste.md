# Explorer on start, image paste into Claude, image preview

## Objective
nvim opens with the file explorer visible (like VS Code); an image copied to the clipboard
can be pasted into the Claude panel; image files can be viewed.

## Problem
- The explorer starts closed.
- Claude Code pastes images on its own key (Ctrl+V on macOS/Linux, Alt+V on Windows) by
  reading the clipboard; inside nvim's terminal that key is taken by nvim mappings or by
  the terminal (Windows Terminal keeps Ctrl+V for text paste, Terminal.app keeps Cmd+V).
- Image files open as binary text.

## Design
- Explorer: open on startup (UI only), focus stays in the editor / start screen.
- Paste in Claude (terminal mode, Claude buffers): our paste keys check the clipboard; with
  an image they send Claude its own image key, with text they paste the text. Alt+V passes
  through to Claude untouched in terminals.
- Images: Snacks image where the terminal speaks the kitty graphics protocol (WezTerm,
  kitty, ghostty); elsewhere image files open in the system viewer. Installers add ImageMagick.

## Tasks
- [x] T1 Explorer open on start.
- [x] T2 Clipboard image paste into Claude (Windows, macOS, Linux).
- [x] T3 Image view: Snacks image or system viewer; ImageMagick in the installers.
- [x] T4 README + F1 entries; pty checks.
- [x] T5 Start screen rows with faint dot leaders (name ···· keys ···· letter), also for sessions.

## Progress
Code written (autocmds, sessions.explorer_open helper also used by updates.lua, clipboard.lua,
images.lua, keymaps, vscode.lua, shortcuts, installers, README). Parent fixed the explorer
stealing focus (focus returned in the picker's on_show).

## Verification evidence
- Explorer open on start: 1 window, focus on the start screen.
- Real image on the Windows clipboard: Ctrl+Shift+V in a Claude terminal sent the same key as
  Alt+V (Claude's image paste); text clipboard pasted "hello"; Alt+V passes through.
- Opening pic.png in a terminal without graphics went to the system viewer, no bytes shown.
- Dot leaders rendered (pyte capture), leader color = Comment without italics.
- Regression: Terminal.app universal keys, Claude links 16/16, markdown keys, F1 65 items,
  install.sh syntax ok.

## Checks
pty: explorer window present after start; Claude terminal receives the image key when the
clipboard holds an image (Windows clipboard test), text otherwise; opening a .png in a
non-graphics terminal launches the viewer instead of showing bytes.

## TDD
Off (config repo); functional pty checks.
