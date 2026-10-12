#!/usr/bin/env bash
# macOS / Linux installer: links nvim + wezterm to this repo. Safe to run more than once.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  already linked: $dest"
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak-$stamp"
    echo "  backup: $dest.bak-$stamp"
  fi
  ln -s "$src" "$dest"
  echo "  linked $dest -> $src"
}

echo "== Neovim"
link "$repo/nvim" "$config/nvim"

echo "== WezTerm"
link "$repo/wezterm" "$config/wezterm"
# ~/.wezterm.lua would win over ~/.config/wezterm/wezterm.lua
if [ -e "$HOME/.wezterm.lua" ] && [ ! -L "$HOME/.wezterm.lua" ]; then
  mv "$HOME/.wezterm.lua" "$HOME/.wezterm.lua.bak-$stamp"
  echo "  backup: $HOME/.wezterm.lua.bak-$stamp"
fi

echo "== Tools"
if [ "$(uname)" = "Darwin" ]; then pm="brew install"; else pm="sudo apt install"; fi
missing=0
for t in nvim git rg fd lazygit node cc tree-sitter wezterm; do
  if ! command -v "$t" >/dev/null 2>&1; then
    missing=1
    case "$t" in
      rg) pkg="ripgrep" ;;
      fd) pkg="fd" ;;
      cc) pkg="gcc" ;;
      node) pkg="node" ;;
      tree-sitter) echo "  missing: tree-sitter -> npm install -g tree-sitter-cli"; continue ;;
      wezterm) echo "  missing: wezterm -> https://wezterm.org/install"; continue ;;
      *) pkg="$t" ;;
    esac
    echo "  missing: $t -> $pm $pkg"
  fi
done
[ "$missing" -eq 0 ] && echo "  all tools present"

echo "Done. Open a new terminal and run: nvim"
