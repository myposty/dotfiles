#!/usr/bin/env bash
# macOS / Linux installer: installs missing tools, links nvim + wezterm to this
# repo, adds the PATH exports to the shell profiles and pre-installs every plugin,
# language server and parser. Safe to run more than once.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Always install the latest version: pull, and if anything changed run the new script
if [ -z "${DOTFILES_PULLED:-}" ] && git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  before="$(git -C "$repo" rev-parse HEAD)"
  echo "== Updating dotfiles"
  # public repo: never ask for credentials (no keychain dialog, no password prompt)
  GIT_TERMINAL_PROMPT=0 git -c credential.helper= -C "$repo" pull --ff-only -q || echo "  could not update (local changes?), installing this version"
  if [ "$(git -C "$repo" rev-parse HEAD)" != "$before" ]; then
    DOTFILES_PULLED=1 exec bash "$repo/install.sh" "$@"
  fi
fi

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

# Which terminal nvim is used in: asked once and remembered. Ask again with
# `bash install.sh --terminal`, or set DOTFILES_TERMINAL=system|wezterm.
choice_file="$config/dotfiles/terminal"
terminal="${DOTFILES_TERMINAL:-}"
if [ -z "$terminal" ] && [ "${1:-}" != "--terminal" ] && [ -f "$choice_file" ]; then
  terminal="$(cat "$choice_file")"
fi
if [ "$terminal" != "system" ] && [ "$terminal" != "wezterm" ]; then
  terminal="system"
  if [ -t 0 ]; then
    if [ "$(uname)" = "Darwin" ]; then system_name="Terminal.app (the one macOS comes with)"; else system_name="the terminal you use now"; fi
    echo "Which terminal do you want to use nvim in?"
    echo "  1) $system_name"
    if [ "$(uname)" = "Darwin" ]; then
      echo "     Looks the same, but macOS keeps Cmd and Ctrl+Shift shortcuts: use the Ctrl ones."
    fi
    echo "  2) WezTerm (gets installed)"
    echo "     Every shortcut works, Cmd+P, Cmd+Shift+P... included."
    printf "Choose 1 or 2 [1]: "
    read -r answer || answer=""
    if [ "$answer" = "2" ]; then terminal="wezterm"; fi
  fi
fi
mkdir -p "$(dirname "$choice_file")"
echo "$terminal" > "$choice_file"
echo "== Terminal: $terminal"

# The config goes in first: whatever happens with the tools below, nvim opens LazyVim
echo "== Neovim config"
link "$repo/nvim" "$config/nvim"
if [ "$terminal" = "wezterm" ]; then
  link "$repo/wezterm" "$config/wezterm"
  # ~/.wezterm.lua would win over ~/.config/wezterm/wezterm.lua
  if [ -e "$HOME/.wezterm.lua" ] && [ ! -L "$HOME/.wezterm.lua" ]; then
    mv "$HOME/.wezterm.lua" "$HOME/.wezterm.lua.bak-$stamp"
    echo "  backup: $HOME/.wezterm.lua.bak-$stamp"
  fi
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
# dots: update everything (dotfiles, tools, plugins) without typing the installer path
alias dots='bash "$HOME/dotfiles/install.sh"'
# nvim restarts itself after a dotfiles update: it quits leaving a marker, and this
# opens it again where it was (renaming the marker first, so it can never loop)
nvim() {
  local marker="${XDG_STATE_HOME:-$HOME/.local/state}/nvim/dotfiles-restart.json"
  NVIM_RESTART_WRAPPER=1 command nvim "$@"
  local code=$?
  while [ -f "$marker" ]; do
    mv -f "$marker" "$marker.resume"
    NVIM_RESTART_WRAPPER=1 command nvim -c "lua require('config.updates').resume()"
    code=$?
  done
  return $code
}
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
    # the official installer; it also installs the Xcode command line tools (C compiler)
    echo "  installing Homebrew (asks for your Mac password)"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [ -x "$brew_bin" ]; then eval "$("$brew_bin" shellenv)"; break; fi
    done
  fi
  have cc || xcode-select --install 2>/dev/null || true
  # tree-sitter-cli is the tree-sitter command; the "tree-sitter" formula is only the library
  for pkg in neovim git ripgrep fd lazygit node tree-sitter-cli python; do
    brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg" || echo "  could not install $pkg"
  done
  # the icons font, for whichever terminal
  brew list --cask font-caskaydia-cove-nerd-font >/dev/null 2>&1 || brew install --cask font-caskaydia-cove-nerd-font
  if [ "$terminal" = "wezterm" ]; then
    brew list --cask wezterm >/dev/null 2>&1 || brew install --cask wezterm
  fi
  # Terminal.app, whatever the terminal choice (it is always there, and the icons and
  # Alt keys must work in it): Nerd Font (icons), dark Monokai Soda colors and Option
  # as Meta (Option+Z, Option+P...). Changes its default profile.
  osascript <<'OSA' >/dev/null 2>&1 || echo "  could not set up Terminal.app (System Settings > Privacy > Automation)"
tell application "Terminal"
  set s to default settings
  set font name of s to "CaskaydiaCoveNFM-Regular"
  set font size of s to 14
  set background color of s to {6682, 6682, 6682}
  set normal text color of s to {63222, 63222, 60652}
  set bold text color of s to {65535, 65535, 65535}
  set cursor color of s to {40092, 25700, 65278}
end tell
OSA
  term_profile="$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || echo Basic)"
  /usr/libexec/PlistBuddy -c "Set ':Window Settings:$term_profile:useOptionAsMetaKey' true" \
    "$HOME/Library/Preferences/com.apple.Terminal.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add ':Window Settings:$term_profile:useOptionAsMetaKey' bool true" \
      "$HOME/Library/Preferences/com.apple.Terminal.plist" 2>/dev/null || true
  # zsh is the shell everywhere on the Mac (WezTerm starts it too)
  if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
    chsh -s /bin/zsh || echo "  could not make zsh the default shell (run: chsh -s /bin/zsh)"
  fi
elif have apt-get; then
  # never ask anything: in an interactive terminal some packages (tzdata) would
  # stop the install waiting for an answer
  apt() { $sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }
  apt update -qq
  apt install -y -qq git curl tar unzip gcc make ripgrep fd-find nodejs npm python3 python3-venv gpg xz-utils fontconfig >/dev/null
  # Debian/Ubuntu name the fd binary "fdfind"
  have fd || ln -sf "$(command -v fdfind)" "$local_bin/fd"
  if [ "$terminal" = "wezterm" ] && ! have wezterm; then
    # official WezTerm apt repository
    curl -fsSL https://apt.fury.io/wez/gpg.key | $sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | $sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    apt update -qq && apt install -y -qq wezterm >/dev/null || echo "  could not install WezTerm"
  fi
elif have dnf; then
  $sudo dnf install -y -q git curl tar unzip gcc make ripgrep fd-find nodejs npm python3 xz fontconfig
  if [ "$terminal" = "wezterm" ] && ! have wezterm; then
    $sudo dnf copr enable -y wezfurlong/wezterm-nightly && $sudo dnf install -y -q wezterm || echo "  could not install WezTerm"
  fi
elif have pacman; then
  $sudo pacman -S --needed --noconfirm git curl tar unzip gcc make ripgrep fd nodejs npm python neovim lazygit xz fontconfig
  if [ "$terminal" = "wezterm" ]; then
    $sudo pacman -S --needed --noconfirm wezterm || echo "  could not install WezTerm"
  fi
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

  # Icons font: Caskaydia Cove Nerd Font for the terminal (failures only warn)
  font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  if ! ls "$font_dir"/CaskaydiaCove*NerdFont* >/dev/null 2>&1; then
    echo "  installing Caskaydia Cove Nerd Font"
    font_tmp="$(mktemp -d)"
    if curl -fsSL -o "$font_tmp/font.tar.xz" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.tar.xz" \
      && tar -xJf "$font_tmp/font.tar.xz" -C "$font_dir" --wildcards \
        'CaskaydiaCoveNerdFont-Regular.ttf' 'CaskaydiaCoveNerdFont-Bold.ttf' \
        'CaskaydiaCoveNerdFontMono-Regular.ttf' 'CaskaydiaCoveNerdFontMono-Bold.ttf'; then
      if have fc-cache; then fc-cache -f "$font_dir" >/dev/null 2>&1 || true; fi
    else
      echo "  could not install the Nerd Font (icons may show as boxes): https://www.nerdfonts.com/font-downloads"
    fi
    rm -rf "$font_tmp"
  fi
  # GNOME Terminal: use it in the default profile (best effort)
  if have gsettings; then
    gt_id="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'" || true)"
    if [ -n "$gt_id" ] && ls "$font_dir"/CaskaydiaCove*NerdFont* >/dev/null 2>&1; then
      gt_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gt_id/"
      gsettings set "$gt_path" use-system-font false 2>/dev/null \
        && gsettings set "$gt_path" font "CaskaydiaCove Nerd Font Mono 12" 2>/dev/null || true
    fi
  fi
fi
# Claude Code (the panel on Ctrl+Shift+A / Alt+C runs it): Anthropic's official installer
if ! have claude; then
  echo "  installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 || echo "  could not install Claude Code (https://claude.com/claude-code)"
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
in_wezterm=""
if [ "${TERM_PROGRAM:-}" = "WezTerm" ] || [ -n "${WEZTERM_PANE:-}" ]; then in_wezterm=1; fi
launch_msg="Done. Opening nvim (your recent sessions are on the start screen: press 1 for the last one)."
if [ "$terminal" = "wezterm" ] && [ -z "$in_wezterm" ] && [ "$(uname)" = "Darwin" ] && [ -d "/Applications/WezTerm.app" ]; then
  if [ "${DOTFILES_NO_LAUNCH:-}" = "1" ]; then
    echo "Done. Opening WezTerm: run nvim there."
    open -a WezTerm
    exit 0
  fi
  echo "$launch_msg"
  wez=/Applications/WezTerm.app/Contents/MacOS/wezterm
  if [ -x "$wez" ]; then
    "$wez" start --cwd "$HOME" -- /bin/zsh -lic 'nvim; exec /bin/zsh -l' >/dev/null 2>&1 &
  fi
  open -a WezTerm # focus it (and the fallback when the binary is missing)
  exit 0
fi
# Leave the user in a shell that already has the new PATH (nothing to reload by hand).
# nvim opens through an interactive login shell so the profile's `nvim` restart
# function exists; quitting nvim drops into that shell.
if [ -t 0 ] && [ -t 1 ]; then
  if [ "${DOTFILES_NO_LAUNCH:-}" = "1" ]; then
    echo "Done. nvim is ready."
    if [ "$(uname)" = "Darwin" ]; then exec /bin/zsh -l; else exec "${SHELL:-/bin/bash}" -l; fi
  fi
  echo "$launch_msg"
  if [ "$(uname)" = "Darwin" ]; then
    exec /bin/zsh -lic 'nvim; exec /bin/zsh -l'
  else
    exec "${SHELL:-/bin/bash}" -lic 'nvim; exec "${SHELL:-/bin/bash}" -l'
  fi
fi
echo "Done. nvim is ready."
