#!/usr/bin/env bash
# macOS / Linux installer: installs missing tools, links nvim + wezterm to this
# repo and pre-installs every plugin, language server and parser.
# Safe to run more than once.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
local_bin="$HOME/.local/bin"
mkdir -p "$local_bin"
orig_path="$PATH"
export PATH="$local_bin:$HOME/.local/nvim/bin:$PATH"

have() { command -v "$1" >/dev/null 2>&1; }

if [ "$(id -u)" -eq 0 ]; then sudo=""; else sudo="sudo"; fi

arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64) arch_nvim="x86_64"; arch_lg="x86_64" ;;
  aarch64 | arm64) arch_nvim="arm64"; arch_lg="arm64" ;;
  *) echo "unsupported architecture: $arch"; exit 1 ;;
esac

nvim_ok() {
  have nvim && nvim --headless -c 'lua io.stdout:write(vim.fn.has("nvim-0.11") == 1 and "ok" or "old")' -c 'qa!' 2>/dev/null | grep -q ok
}

echo "== Tools"
if [ "$(uname)" = "Darwin" ]; then
  if ! have brew; then
    echo "  Homebrew is required: https://brew.sh"; exit 1
  fi
  have cc || xcode-select --install || true
  for pkg in neovim git ripgrep fd lazygit node tree-sitter python; do
    brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
  done
  brew list --cask wezterm >/dev/null 2>&1 || brew install --cask wezterm || true
  brew list --cask font-caskaydia-cove-nerd-font >/dev/null 2>&1 || brew install --cask font-caskaydia-cove-nerd-font || true
elif have apt-get; then
  $sudo apt-get update -qq
  $sudo apt-get install -y -qq git curl tar unzip gcc make ripgrep fd-find nodejs npm python3 python3-venv >/dev/null
  # Debian/Ubuntu name the fd binary "fdfind"
  have fd || ln -sf "$(command -v fdfind)" "$local_bin/fd"
elif have dnf; then
  $sudo dnf install -y -q git curl tar unzip gcc make ripgrep fd-find nodejs npm python3
elif have pacman; then
  $sudo pacman -S --needed --noconfirm git curl tar unzip gcc make ripgrep fd nodejs npm python neovim lazygit
else
  echo "  unknown package manager: install git, curl, gcc, ripgrep, fd, node, npm and python3, then run again"
  exit 1
fi

if [ "$(uname)" != "Darwin" ]; then
  # Distro packages of Neovim are often too old for LazyVim: use the official build
  if ! nvim_ok; then
    echo "  installing Neovim (official release)"
    rm -rf "$HOME/.local/nvim"
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch_nvim}.tar.gz" | tar -xz -C "$HOME/.local"
    mv "$HOME/.local/nvim-linux-${arch_nvim}" "$HOME/.local/nvim"
    ln -sf "$HOME/.local/nvim/bin/nvim" "$local_bin/nvim"
  fi
  if ! have lazygit; then
    echo "  installing lazygit"
    version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -o '"tag_name": *"v[^"]*"' | grep -o '[0-9][0-9.]*')"
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch_lg}.tar.gz" | tar -xz -C "$local_bin" lazygit
  fi
  if ! have tree-sitter; then
    echo "  installing tree-sitter CLI"
    npm install -g --silent --prefix "$HOME/.local" tree-sitter-cli
  fi
fi
for t in nvim git rg fd lazygit node cc tree-sitter python3; do
  have "$t" || { echo "  missing after install: $t"; exit 1; }
done
echo "  all tools present"

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

echo "== Plugins, language servers and parsers (first run takes a few minutes)"
nvim --headless -c "luafile $repo/bootstrap.lua"

case ":$orig_path:" in *":$local_bin:"*) ;; *) echo "Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;; esac
echo "Done. Open a new terminal and run: nvim"
