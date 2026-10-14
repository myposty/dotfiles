# Windows installer: links nvim + wezterm to this repo and adds the
# Neovim key forwarding to Windows Terminal. Safe to run more than once.
$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup($path) {
  if (Test-Path $path) {
    $item = Get-Item $path -Force
    if ($item.LinkType) { Remove-Item $path -Force -Recurse; return }
    Move-Item $path "$path.bak-$stamp"
    Write-Host "  backup: $path.bak-$stamp"
  }
}

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host "== Tools"
$tools = [ordered]@{
  "git" = "Git.Git"; "nvim" = "Neovim.Neovim"; "rg" = "BurntSushi.ripgrep.MSVC"; "fd" = "sharkdp.fd";
  "lazygit" = "JesseDuffield.lazygit"; "node" = "OpenJS.NodeJS.LTS"; "gcc" = "BrechtSanders.WinLibs.POSIX.UCRT";
  "python" = "Python.Python.3.13"; "wezterm" = "wez.wezterm"
}
function Test-Tool($name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  # The Microsoft Store "python" alias exists even when Python is not installed
  return $cmd -and -not ($name -eq "python" -and $cmd.Source -match "WindowsApps")
}

Refresh-Path
foreach ($t in $tools.Keys) {
  if (-not (Test-Tool $t)) {
    Write-Host "  installing $t"
    winget install --id=$($tools[$t]) -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    Refresh-Path
  }
}
if (-not (Get-Command tree-sitter -ErrorAction SilentlyContinue)) {
  Write-Host "  installing tree-sitter CLI"
  npm install -g --silent tree-sitter-cli | Out-Null
  Refresh-Path
  # npm's global bin folder is not always on the registry PATH yet (fresh Node install)
  $npmBin = (npm prefix -g)
  if ($npmBin -and ($env:Path -split ";") -notcontains $npmBin) { $env:Path += ";$npmBin" }
}
# chafa: draws images inside nvim in terminals without graphics (Windows Terminal)
if (-not (Get-Command chafa -ErrorAction SilentlyContinue)) {
  Write-Host "  installing chafa"
  try {
    winget install -e --id hpjansson.Chafa --accept-source-agreements --accept-package-agreements | Out-Null
    Refresh-Path
  } catch {
    Write-Warning "could not install chafa (images then open in the system viewer): $_"
  }
}
# ImageMagick: Snacks image converts image formats with `magick` (optional, only warns)
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  Write-Host "  installing ImageMagick"
  try {
    winget install -e --id ImageMagick.ImageMagick --accept-source-agreements --accept-package-agreements | Out-Null
    Refresh-Path
  } catch {
    Write-Warning "could not install ImageMagick (image preview needs it): $_"
  }
}
$missing = @($tools.Keys) + "tree-sitter" | Where-Object { -not (Test-Tool $_) }
if ($missing) { throw "missing after install: $($missing -join ', '). Open a new terminal and run this again." }
Write-Host "  all tools present"

Write-Host "== Neovim"
$nvim = Join-Path $env:LOCALAPPDATA "nvim"
$current = Get-Item $nvim -Force -ErrorAction SilentlyContinue
if ($current -and $current.LinkType -eq "Junction" -and $current.Target -contains (Join-Path $repo "nvim")) {
  Write-Host "  already linked"
} else {
  Backup $nvim
  New-Item -ItemType Junction -Path $nvim -Target (Join-Path $repo "nvim") | Out-Null
  Write-Host "  linked $nvim -> $repo\nvim"
}

Write-Host "== WezTerm"
$wezDir = Join-Path $env:USERPROFILE ".config\wezterm"
$wezRepo = Join-Path $repo "wezterm"
$current = Get-Item $wezDir -Force -ErrorAction SilentlyContinue
if ($current -and $current.LinkType -eq "Junction" -and $current.Target -contains $wezRepo) {
  Write-Host "  already linked"
} else {
  # Keep local fonts (not versioned) by moving them into the linked folder
  $oldFonts = Join-Path $wezDir "fonts"
  if ($current -and -not $current.LinkType -and (Test-Path $oldFonts) -and -not (Test-Path (Join-Path $wezRepo "fonts"))) {
    Move-Item $oldFonts (Join-Path $wezRepo "fonts")
    Write-Host "  fonts moved into $wezRepo\fonts"
  }
  New-Item -ItemType Directory (Split-Path $wezDir) -Force | Out-Null
  Backup $wezDir
  New-Item -ItemType Junction -Path $wezDir -Target $wezRepo | Out-Null
  Write-Host "  linked $wezDir -> $wezRepo"
}
# ~/.wezterm.lua would win over ~/.config/wezterm/wezterm.lua
Backup (Join-Path $env:USERPROFILE ".wezterm.lua")
if (-not (Test-Path (Join-Path $wezDir "fonts"))) {
  Write-Host "  note: no fonts in $wezDir\fonts; WezTerm uses its built-in font until you copy a Nerd Font there"
}

Write-Host "== Windows Terminal"
$wt = Get-ChildItem (Join-Path $env:LOCALAPPDATA "Packages") -Directory -Filter "Microsoft.WindowsTerminal*" -ErrorAction SilentlyContinue |
  ForEach-Object { Join-Path $_.FullName "LocalState\settings.json" } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wt) {
  Write-Host "  not installed, skipped"
} else {
  $settings = Get-Content $wt -Raw | ConvertFrom-Json
  $keys = Get-Content (Join-Path $repo "windows-terminal\nvim-keys.json") -Raw | ConvertFrom-Json
  if (-not $settings.actions) { $settings | Add-Member actions @() -Force }
  if (-not $settings.keybindings) { $settings | Add-Member keybindings @() -Force }
  $ourKeys = $keys.keybindings | ForEach-Object { $_.keys }
  $actions = @($settings.actions | Where-Object { $keys.actions.id -notcontains $_.id }) + $keys.actions
  # Free the keys we need; a conflicting binding (e.g. WT find on ctrl+shift+f) moves to ctrl+alt+shift
  $bindings = @()
  foreach ($b in $settings.keybindings) {
    if ($keys.keybindings.id -contains $b.id) { continue }
    if ($ourKeys -contains $b.keys) {
      $b.keys = $b.keys -replace "^ctrl\+shift\+", "ctrl+alt+shift+"
      Write-Host "  moved $($b.id) to $($b.keys)"
    }
    $bindings += $b
  }
  $bindings += $keys.keybindings
  $settings.actions = $actions
  $settings.keybindings = $bindings
  Copy-Item $wt "$wt.bak-$stamp"
  [IO.File]::WriteAllText($wt, ($settings | ConvertTo-Json -Depth 32))
  Write-Host "  $($keys.keybindings.Count) nvim key bindings in place (backup: $wt.bak-$stamp)"
}

Write-Host "== Claude Code"
# the panel on Ctrl+Shift+A / Alt+C runs it: Anthropic's official installer when missing
if (Get-Command claude -ErrorAction SilentlyContinue) {
  Write-Host "  already installed"
} elseif ($env:CI) {
  Write-Host "  skipped in CI"
} else {
  try {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Refresh-Path
  } catch {
    Write-Host "  could not install Claude Code (https://claude.com/claude-code)"
  }
}

Write-Host "== Shell profiles (nvim restarts itself after a dotfiles update)"
# nvim quits leaving a marker after an update; these `nvim` functions open it again
# where it was. The marker is renamed before reopening, so it can never loop.
$psBlock = @'
# >>> dotfiles >>>
function nvim {
  $marker = Join-Path $env:LOCALAPPDATA "nvim-data\dotfiles-restart.json"
  $env:NVIM_RESTART_WRAPPER = "1"
  & nvim.exe @args
  while (Test-Path $marker) {
    Move-Item -Force $marker "$marker.resume"
    & nvim.exe -c "lua require('config.updates').resume()"
  }
  Remove-Item Env:\NVIM_RESTART_WRAPPER -ErrorAction SilentlyContinue
}
# <<< dotfiles <<<
'@
$bashBlock = @'
# >>> dotfiles >>>
nvim() {
  local marker="$LOCALAPPDATA/nvim-data/dotfiles-restart.json"
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
'@
function Set-Block($file, $block) {
  New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
  $text = if (Test-Path $file) { [IO.File]::ReadAllText($file) } else { "" }
  # replace an earlier block instead of adding a second one
  $text = [regex]::Replace($text, "(?s)# >>> dotfiles >>>.*?# <<< dotfiles <<<\r?\n?", "")
  $text = $text.TrimEnd() + $(if ($text.Trim()) { "`n`n" } else { "" }) + ($block -replace "`r`n", "`n") + "`n"
  [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding $false))
  Write-Host "  updated $file"
}
$docs = [Environment]::GetFolderPath("MyDocuments")
Set-Block (Join-Path $docs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1") $psBlock
Set-Block (Join-Path $docs "PowerShell\Microsoft.PowerShell_profile.ps1") $psBlock
Set-Block (Join-Path $env:USERPROFILE ".bashrc") $bashBlock

Write-Host "== Plugins, language servers and parsers (first run takes a few minutes)"
nvim --headless -c "luafile $($repo -replace '\\', '/')/bootstrap.lua"
if ($LASTEXITCODE -ne 0) { throw "nvim bootstrap failed (see FAILED line above)" }

if ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected -and $env:DOTFILES_NO_LAUNCH -ne "1") {
  Write-Host "Done. Opening nvim (your recent sessions are on the start screen: press 1 for the last one)."
  # same loop as the profile function: an update leaves a marker and nvim reopens in place
  $marker = Join-Path $env:LOCALAPPDATA "nvim-data\dotfiles-restart.json"
  $env:NVIM_RESTART_WRAPPER = "1"
  & nvim.exe
  while (Test-Path $marker) {
    Move-Item -Force $marker "$marker.resume"
    & nvim.exe -c "lua require('config.updates').resume()"
  }
  Remove-Item Env:\NVIM_RESTART_WRAPPER -ErrorAction SilentlyContinue
} else {
  Write-Host "Done. Open a new terminal and run: nvim"
}
