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

Write-Host "== Plugins, language servers and parsers (first run takes a few minutes)"
nvim --headless -c "luafile $($repo -replace '\\', '/')/bootstrap.lua"
if ($LASTEXITCODE -ne 0) { throw "nvim bootstrap failed (see FAILED line above)" }

Write-Host "Done. Open a new terminal and run: nvim"
