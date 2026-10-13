#!/usr/bin/env bash
# macOS / Linux installer: installs missing tools, links nvim + wezterm to this
# repo, adds the PATH exports to the shell profiles and pre-installs every plugin,
# language server and parser. Safe to run more than once.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
local_bin="$HOME/.local/bin"
mkdir -p "$local_bin"

have() { command -v "$1" >/dev/null 2>&1; }

# Homebrew is often installed but not on PATH yet (Apple Silicon: /opt/homebrew)
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done
export PATH="$local_bin:$HOME/.local/nvim/bin:$PATH"

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

# The config goes in first: whatever happens with the tools below, nvim opens LazyVim
echo "== Neovim and WezTerm config"
link "$repo/nvim" "$config/nvim"
link "$repo/wezterm" "$config/wezterm"
# ~/.wezterm.lua would win over ~/.config/wezterm/wezterm.lua
if [ -e "$HOME/.wezterm.lua" ] && [ ! -L "$HOME/.wezterm.lua" ]; then
  mv "$HOME/.wezterm.lua" "$HOME/.wezterm.lua.bak-$stamp"
  echo "  backup: $HOME/.wezterm.lua.bak-$stamp"
fi

echo "== Shell profile (PATH for brew, nvim and the tools installed here)"
profile_block() {
  cat <<'EOF'
# >>> dotfiles >>>
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$brew_bin" ]; then eval "$("$brew_bin" shellenv)"; break; fi
done
export PATH="$HOME/.local/bin:$HOME/.local/nvim/bin:$PATH"
export EDITOR=nvim VISUAL=nvim
# <<< dotfiles <<<
EOF
}
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  # zsh is the macOS default shell; bash everywhere else. Only touch the ones in use.
  case "$rc" in
    *zshrc) [ "$(uname)" = "Darwin" ] || [ -e "$rc" ] || continue ;;
    *bashrc) [ "$(uname)" != "Darwin" ] || [ -e "$rc" ] || continue ;;
  esac
  touch "$rc"
  # replace an earlier block instead of adding a second one
  awk '/^# >>> dotfiles >>>$/{skip=1} !skip{print} /^# <<< dotfiles <<<$/{skip=0}' "$rc" > "$rc.dotfiles-tmp"
  profile_block >> "$rc.dotfiles-tmp"
  mv "$rc.dotfiles-tmp" "$rc"
  echo "  updated $rc"
done
# macOS opens login shells: make bash read .bashrc there too
if [ "$(uname)" = "Darwin" ] && [ -e "$HOME/.bashrc" ] && ! grep -qs "bashrc" "$HOME/.bash_profile"; then
  echo '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"' >> "$HOME/.bash_profile"
fi

echo "== Tools"
if [ "$(uname)" = "Darwin" ]; then
  if ! have brew; then
    echo "  Homebrew is required: https://brew.sh (then run this again)"; exit 1
  fi
  have cc || xcode-select --install 2>/dev/null || true
  # tree-sitter-cli is the tree-sitter command; the "tree-sitter" formula is only the library
  for pkg in neovim git ripgrep fd lazygit node tree-sitter-cli python; do
    brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg" || echo "  could not install $pkg"
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
fi
# Last resort for the tree-sitter command on any OS: the npm package
if ! have tree-sitter && have npm; then
  echo "  installing tree-sitter CLI (npm)"
  npm install -g --silent --prefix "$HOME/.local" tree-sitter-cli || true
fi

if ! nvim_ok; then
  echo "  Neovim 0.11+ is missing: install it and run this again"; exit 1
fi
missing=""
for t in git rg fd lazygit node cc tree-sitter python3; do
  have "$t" || missing="$missing $t"
done
if [ -n "$missing" ]; then
  echo "  WARNING, still missing:$missing (nvim works; the features that need them do not)"
else
  echo "  all tools present"
fi

echo "== Plugins, language servers and parsers (first run takes a few minutes)"
nvim --headless -c "luafile $repo/bootstrap.lua"

echo
echo "Done. Load the new PATH in this terminal (or open a new one), then run nvim:"
echo "  exec \$SHELL -l"
