-- wezterm.lua — LOGICA. No hace falta tocar este archivo.
-- Tus opciones estan en config.lua; los temas en themes.lua.
-- Referencia de estilo: Gentleman.Dots. Adaptado a Windows + Git Bash.

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- config.lua y themes.lua viven al lado de este archivo (repo dotfiles). Se
-- cargan con dofile por RUTA ABSOLUTA (no require), porque require depende de
-- package.path y ese difiere segun desde donde se abra WezTerm. Si no estan al
-- lado, se buscan en el HOME (instalacion vieja). Si falla, se usa fallback.
local home = (os.getenv("HOME") or os.getenv("USERPROFILE") or "C:\\Users\\Public"):gsub("\\", "/")
local here = (wezterm.config_dir or home):gsub("\\", "/")
local function load_lua(name)
  for _, dir in ipairs({ here, home }) do
    local ok, result = pcall(dofile, dir .. "/" .. name .. ".lua")
    if ok and type(result) == "table" then return result end
  end
  return nil
end
local user = load_lua("config") or {}
local themes = load_lua("themes")  -- nil si no se pudo cargar

-- --- Idioma para los textos de la UI (ej. confirmar cierre) ------------------
-- Windows deja LANG vacio, asi que el idioma se elige en config.lua (language).
-- "auto" intenta detectarlo del entorno; si no puede, usa ingles.
local lang_pref = (user.language or "auto"):lower()
local is_es
if lang_pref == "es" then is_es = true
elseif lang_pref == "en" then is_es = false
else
  local sys_lang = (os.getenv("LANG") or os.getenv("LANGUAGE") or os.getenv("LC_ALL") or ""):lower()
  is_es = sys_lang:find("es") == 1
end
local L = is_es and {
  close_title = "  Cerrar esta ventana?",
  close_yes = "  Si, cerrar",
  close_no = "  No, volver",
} or {
  close_title = "  Close this window?",
  close_yes = "  Yes, close",
  close_no = "  No, go back",
}

-- Valores por defecto: si config.lua no define algo, se usa esto.
local function default(v, d) if v == nil then return d else return v end end
user.theme        = default(user.theme, "indigo")
user.opacity      = default(user.opacity, 0.82)
user.win_backdrop = default(user.win_backdrop, "Acrylic")
user.mac_blur     = default(user.mac_blur, 20)
user.font           = default(user.font, "CaskaydiaCove Nerd Font")
user.font_size      = default(user.font_size, 12.0)
user.line_height    = default(user.line_height, 1.1)
user.font_ligatures = default(user.font_ligatures, false)
user.window_buttons        = default(user.window_buttons, true)
user.tabs_at_bottom        = default(user.tabs_at_bottom, true)
user.hide_tabs_when_single = default(user.hide_tabs_when_single, true)
user.sys_meter        = default(user.sys_meter, true)   -- RAM/CPU/reloj en vivo en la barra
user.padding          = default(user.padding, 10)
user.confirm_close    = default(user.confirm_close, true)
user.scrollback_lines = default(user.scrollback_lines, 10000)
user.windows_shell    = default(user.windows_shell, "C:/Program Files/Git/bin/bash.exe")

-- --- Shell (solo Windows; Mac/Linux usan el del sistema) --------------------
-- `-l` (login), NO `-i`. Se probo `-i` para saltear /etc/profile (~180ms) pero
-- ROMPE: /etc/profile es lo que exporta TMPDIR / ORIGINAL_TMP / MINGW_PREFIX y
-- demas del entorno MSYS. Sin esas, las apps que escriben temporales (claude,
-- que es Node; fzf) mueren y se llevan la terminal. 180ms no valen eso.
if wezterm.target_triple:find("windows") and user.windows_shell then
  config.default_prog = { user.windows_shell, "-l" }
end

-- --- Fuente -----------------------------------------------------------------
-- WORKAROUND crash de WezTerm en Windows: al hacer fallback de glifos, WezTerm
-- enumera la coleccion de fuentes del sistema via DirectWrite (dwrote), y una
-- fuente del sistema corrupta lo hace PANIQUEAR y cerrar toda la ventana (pasa
-- con TUIs llenas de glifos: claude, fzf). Con ConfigDirsOnly, WezTerm usa SOLO
-- las fuentes de esta carpeta (tu Nerd Font, copiada por el install) y NO toca
-- la coleccion del sistema -> no hay panic. Solo Windows; Mac/Linux no lo sufren.
if wezterm.target_triple:find("windows") then
  config.font_dirs = { wezterm.home_dir .. "/.config/wezterm/fonts" }
  config.font_locator = "ConfigDirsOnly"
end
config.font = wezterm.font_with_fallback({ user.font, "Cascadia Mono" })
config.font_size = user.font_size
config.line_height = user.line_height
config.scrollback_lines = user.scrollback_lines
-- Ligaduras: harfbuzz_features va a nivel config (global), NO dentro de la fuente.
-- Si font_ligatures=false, se apagan con calt/clig/liga = 0.
if not user.font_ligatures then
  config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
end

-- --- Tema (resuelto desde themes.lua; si falta todo, cae a un indigo COMPLETO) --
-- Fallback con arrays LLENOS (nunca {}), o WezTerm rompe con "Object to array".
local fallback = {
  foreground = "#E4E4EF", background = "#1A1A2A", cursor = "#6C6C9E", selection = "#3B3B5C",
  ansi    = { "#2E2E4A", "#9E5C6C", "#6C6C9E", "#8A7A5C", "#4B4B7A", "#7A6C9E", "#565676", "#E4E4EF" },
  brights = { "#3B3B5C", "#b57a8a", "#8a8aba", "#a89a72", "#6c6c9e", "#9a8aba", "#7a7a9a", "#ffffff" },
  tab_active = "#4B4B7A", tab_inactive = "#2E2E4A",
}
local t = (themes and (themes[user.theme] or themes["indigo"])) or fallback
config.colors = {
  foreground = t.foreground,
  background = t.background,
  cursor_bg = t.cursor, cursor_border = t.cursor, cursor_fg = t.background,
  selection_bg = t.selection, selection_fg = t.foreground,
  -- Thumb del scrollbar: el default es casi invisible. Lo atamos al color del
  -- cursor del tema -> visible y se adapta a cada paleta automaticamente.
  scrollbar_thumb = t.cursor,
  ansi = t.ansi, brights = t.brights,
  tab_bar = {
    background = t.background,
    active_tab       = { bg_color = t.tab_active,   fg_color = t.foreground },
    inactive_tab     = { bg_color = t.tab_inactive, fg_color = t.foreground },
    inactive_tab_hover = { bg_color = t.selection,  fg_color = t.foreground },
    new_tab          = { bg_color = t.tab_inactive, fg_color = t.foreground },
  },
}

-- --- Fondo: blur / transparencia --------------------------------------------
-- window_background_opacity: transparencia simple, funciona en TODA version.
config.window_background_opacity = user.opacity
-- win32_system_backdrop (Acrylic/Mica) = blur REAL del escritorio, pero SOLO
-- en builds de WezTerm posteriores a 2024-03. En versiones viejas se ignora en
-- silencio (por eso "no se ve el blur"). Se activa solo si el usuario lo pide y
-- deja de aplicarse con "Disable".
if user.win_backdrop and user.win_backdrop ~= "Disable" then
  config.win32_system_backdrop = user.win_backdrop
end
config.macos_window_background_blur = user.mac_blur

-- --- Ventana ----------------------------------------------------------------
config.window_decorations = user.window_buttons and "TITLE | RESIZE" or "RESIZE"
-- Scrollbar a la derecha. Se dibuja DENTRO del padding derecho, asi que le damos
-- un minimo de 16px para que no quede pegado/cortado (el resto de lados usa tu padding).
config.enable_scroll_bar = true
config.window_padding = { left = user.padding, right = math.max(user.padding, 16), top = user.padding, bottom = user.padding }
config.use_fancy_tab_bar = false
-- El medidor en vivo (RAM/CPU/reloj) vive en la barra; si esta encendido, la
-- barra debe quedar SIEMPRE visible (si no, con una sola pestana se esconde).
config.hide_tab_bar_if_only_one_tab = (not user.sys_meter) and user.hide_tabs_when_single
-- El reloj de la barra late cada segundo; RAM/CPU se releen cada 2s (throttle interno).
config.status_update_interval = 1000
config.tab_bar_at_bottom = user.tabs_at_bottom

-- --- Confirmacion al cerrar (en el IDIOMA del sistema) ----------------------
-- WezTerm tiene "Really kill this window?" HARDCODEADO en ingles, no se traduce.
-- Solucion: apagamos la confirmacion nativa y mostramos la nuestra, que SI
-- podemos escribir en espanol/ingles segun el idioma detectado arriba.
config.window_close_confirmation = "NeverPrompt"

if user.confirm_close then
  wezterm.on("window-close-requested", function(window, pane)
    -- Si solo hay un shell inactivo, cerrar directo (sin molestar).
    local procs = pane and pane:get_foreground_process_name() or ""
    procs = procs:lower()
    local idle = procs:find("bash") or procs:find("\\sh") or procs:find("zsh")
              or procs:find("cmd.exe") or procs:find("powershell") or procs:find("pwsh")
    if idle then return true end  -- deja cerrar sin preguntar

    -- Hay un proceso corriendo -> preguntamos en el idioma del sistema.
    window:perform_action(wezterm.action.InputSelector({
      title = L.close_title,
      choices = { { id = "yes", label = L.close_yes }, { id = "no", label = L.close_no } },
      action = wezterm.action_callback(function(win, _, id, _)
        if id == "yes" then win:perform_action(wezterm.action.QuitApplication, win:active_pane()) end
      end),
    }), pane)
    return false  -- cancelamos el cierre nativo; decide nuestro dialogo
  end)
end

-- --- Rendimiento ------------------------------------------------------------
config.max_fps = 120
config.animation_fps = 60
config.front_end = "WebGpu"

-- --- Nombre de la terminal --------------------------------------------------
-- Titulo de la ventana y de las pestanas: "fuse-termux" en vez de "bash.exe".
local TERM_NAME = "fuse-termux"
config.window_frame = { font = wezterm.font({ family = user.font or "CaskaydiaCove Nerd Font" }) }
wezterm.on("format-window-title", function() return TERM_NAME end)
wezterm.on("format-tab-title", function(tab)
  -- Si le pusiste un nombre a mano (Ctrl+Shift+N), respetalo; si no, el nombre
  -- por defecto + el numero de pestana.
  local i = tab.tab_index + 1
  local name = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title or TERM_NAME
  return string.format("  %s %d  ", name, i)
end)

-- ============================================================================
--  MEDIDOR EN VIVO — RAM / CPU / reloj en la barra (borde de la ventana).
--  Se refresca SOLO cada 1s desde el loop de WezTerm (status_update_interval):
--  cambia estando QUIETO, sin tipear nada. Es el reloj/medidor VIVO; el del
--  prompt es un snapshot por comando (un prompt no puede latir solo).
--  Se apaga con sys_meter=false en config.lua.
-- ============================================================================
if user.sys_meter then
  -- SIN daemon (moria al cerrar la pestana y dejaba todo congelado). La barra
  -- lee /proc DIRECTO cada segundo con un bash chico y calcula el delta de CPU
  -- entre ticks -> RAM/CPU cambian solos, estando quieto. WezTerm es nativo (no
  -- ve /proc), por eso corre bash; es una lectura instantanea (sin sleep).
  local shell = wezterm.target_triple:find("windows") and user.windows_shell or "/bin/sh"
  local probe = 'if [ -r /proc/stat ]; then head -n1 /proc/stat; grep -E "^MemTotal:|^MemAvailable:|^MemFree:" /proc/meminfo; fi'
  local prev_idle, prev_total

  wezterm.on("update-status", function(window, _)
    local ram, cpu
    local ok, _, out = pcall(wezterm.run_child_process, { shell, "-c", probe })
    if ok and out and out ~= "" then
      local cpuline = out:match("cpu%s+([%d ]+)")
      if cpuline then
        local total, idle, i = 0, 0, 0
        for n in cpuline:gmatch("%d+") do i = i + 1; local v = tonumber(n); total = total + v; if i == 4 then idle = v end end
        if prev_total and total > prev_total then
          local dt, di = total - prev_total, idle - prev_idle
          cpu = math.floor((100 * (dt - di)) / dt)
        end
        prev_idle, prev_total = idle, total
      end
      local mt = tonumber(out:match("MemTotal:%s+(%d+)"))
      -- MSYS a veces no expone MemAvailable -> caemos a MemFree.
      local ma = tonumber(out:match("MemAvailable:%s+(%d+)")) or tonumber(out:match("MemFree:%s+(%d+)"))
      if mt and ma and mt > 0 then ram = math.floor((mt - ma) * 100 / mt) end
    end
    local parts = {}
    if ram then table.insert(parts, "RAM " .. ram .. "%") end
    if cpu then table.insert(parts, "CPU " .. cpu .. "%") end
    -- Bateria via API nativa de WezTerm (vacia en PC de mesa -> no se muestra).
    local batt = wezterm.battery_info()
    if batt and #batt > 0 then
      local b = batt[1]
      local pct = math.floor((b.state_of_charge or 0) * 100 + 0.5)
      local icon = utf8.char(0xF0079)                                  -- bateria
      if b.state == "Charging" or b.state == "Full" then icon = utf8.char(0xF0084)  -- enchufada
      elseif pct <= 15 then icon = utf8.char(0xF0083) end              -- baja
      table.insert(parts, icon .. " " .. pct .. "%")
    end
    table.insert(parts, os.date("%H:%M:%S"))
    window:set_right_status(wezterm.format({
      { Foreground = { Color = t.foreground } },
      { Text = "  " .. table.concat(parts, "   ") .. "  " },
    }))
  end)
end

-- ============================================================================
--  PANEL DE CONTROL EN VIVO — cambiar opacidad/blur/tema con el teclado,
--  sin abrir ningun archivo. Los cambios son de la sesion; para dejarlos
--  permanentes, editas config.lua.
-- ============================================================================
local act = wezterm.action

-- Sube/baja la opacidad de la ventana activa en pasos de 0.05.
local function adjust_opacity(delta)
  return wezterm.action_callback(function(window, _)
    local ov = window:get_config_overrides() or {}
    local cur = ov.window_background_opacity or user.opacity
    local nv = cur + delta
    if nv > 1.0 then nv = 1.0 elseif nv < 0.30 then nv = 0.30 end
    ov.window_background_opacity = nv
    window:set_config_overrides(ov)
    window:toast_notification("WezTerm", string.format("Opacidad: %.0f%%", nv * 100), nil, 1500)
  end)
end

-- Activa/desactiva el blur (Acrylic) de la ventana activa.
local function toggle_blur()
  return wezterm.action_callback(function(window, _)
    local ov = window:get_config_overrides() or {}
    if ov.win32_system_backdrop == "Disable" then
      ov.win32_system_backdrop = "Acrylic"; ov.macos_window_background_blur = 20
      window:toast_notification("WezTerm", "Blur: ON", nil, 1500)
    else
      ov.win32_system_backdrop = "Disable"; ov.macos_window_background_blur = 0
      window:toast_notification("WezTerm", "Blur: OFF", nil, 1500)
    end
    window:set_config_overrides(ov)
  end)
end

-- Aplica un tema a la ventana Y avisa al shell (para que el prompt lo siga).
local function apply_theme(win, th, name)
  local ov = win:get_config_overrides() or {}
  ov.colors = {
    foreground = th.foreground, background = th.background,
    cursor_bg = th.cursor, cursor_border = th.cursor, cursor_fg = th.background,
    selection_bg = th.selection, selection_fg = th.foreground,
    ansi = th.ansi, brights = th.brights,
  }
  win:set_config_overrides(ov)
  -- El PROMPT: le mandamos al shell el comando __settheme, que re-inicializa
  -- oh-my-posh con el tema nuevo (recarga REAL). WezTerm no escribe archivos
  -- (io.open falla en Windows); solo manda el comando y bash hace el resto.
  if name then
    local pane = win:active_pane()
    if pane then pane:send_text("__settheme " .. name .. "\n") end
  end
end

-- Lista ordenada de nombres de temas (para ciclar).
local _theme_names = {}
if themes then
  for n, _ in pairs(themes) do table.insert(_theme_names, n) end
  table.sort(_theme_names)
end
local _theme_idx = 1

-- Cicla al tema siguiente/anterior y lo APLICA EN VIVO. Como InputSelector no
-- tiene preview al navegar, esto es mejor: ves cada tema en la terminal COMPLETA.
-- Ctrl+Shift+Derecha = siguiente, Ctrl+Shift+Izquierda = anterior.
local function cycle_theme(dir)
  return wezterm.action_callback(function(window, _)
    if #_theme_names == 0 then return end
    _theme_idx = ((_theme_idx - 1 + dir) % #_theme_names) + 1
    local name = _theme_names[_theme_idx]
    apply_theme(window, themes[name], name)
    window:toast_notification("WezTerm", "Tema: " .. name .. "  (" .. _theme_idx .. "/" .. #_theme_names .. ")", nil, 1200)
  end)
end

-- Menu de temas CON VISTA PREVIA de la paleta (Ctrl+Shift+P).
-- Cada opcion muestra bloques de color del tema al lado del nombre, asi ves
-- como se ve ANTES de aplicarlo. Enter lo aplica; ESC cancela.
local function theme_picker()
  return wezterm.action_callback(function(window, pane)
    if not themes then return end
    local names = {}
    for name, _ in pairs(themes) do table.insert(names, name) end
    table.sort(names)
    local choices = {}
    for _, name in ipairs(names) do
      local th = themes[name]
      -- Nombre a ANCHO FIJO (18) para que las barras arranquen todas parejas.
      local padded = string.format(" %-18s ", name)
      local swatch = {
        "ResetAttributes",
        { Background = { Color = th.background } },
        { Foreground = { Color = th.foreground } },
        { Text = padded },
      }
      -- Paleta: 6 colores en bloques del MISMO ancho, pegados, sin fondo entre medio.
      local palette = { th.ansi[2], th.ansi[3], th.ansi[4], th.ansi[5], th.ansi[6], th.cursor }
      for _, c in ipairs(palette) do
        table.insert(swatch, { Background = { Color = c } })
        table.insert(swatch, { Text = "   " })  -- 3 espacios = bloque de color parejo
      end
      table.insert(swatch, "ResetAttributes")
      table.insert(choices, { label = wezterm.format(swatch), id = name })
    end
    window:perform_action(act.InputSelector({
      title = "Elegi un tema  (las barras de color son la paleta de cada uno)",
      choices = choices,
      action = wezterm.action_callback(function(win, _, id, _)
        if not id then return end
        apply_theme(win, themes[id], id)
        win:toast_notification("WezTerm", "Tema: " .. id, nil, 1500)
      end),
    }), pane)
  end)
end

-- HELPER VISIBLE: un cheatsheet en pantalla con TODOS los atajos.
-- Se abre con Ctrl+Shift+Space. Apretas la tecla que muestra y ejecuta la accion;
-- ESC para salir sin hacer nada. No hay que memorizar nada.
local function help_menu()
  return wezterm.action_callback(function(window, pane)
    window:perform_action(act.InputSelector({
      title = "  Atajos de WezTerm  (ESC para cerrar)",
      choices = {
        { id = "split-h", label = "  Dividir panel  ->  horizontal        (Ctrl+Shift+D)" },
        { id = "split-v", label = "  Dividir panel  ->  vertical          (Ctrl+Shift+E)" },
        { id = "close",   label = "  Cerrar panel actual                  (Ctrl+Shift+W)" },
        { id = "tab",     label = "  Nueva pestana                        (Ctrl+Shift+T)" },
        { id = "op-up",   label = "  Opacidad +  (mas solido)             (F12)" },
        { id = "op-down", label = "  Opacidad -  (mas transparente)       (F11)" },
        { id = "blur",    label = "  Blur ON / OFF                        (Ctrl+Shift+B)" },
        { id = "theme",   label = "  Elegir tema                          (Ctrl+Shift+P)" },
        { id = "zoom0",   label = "  Resetear zoom de fuente              (Ctrl+Shift+0)" },
        { id = "reload",  label = "  Recargar config.lua                  (Ctrl+Shift+R)" },
      },
      action = wezterm.action_callback(function(win, p, id, _)
        if id == "split-h" then win:perform_action(act.SplitHorizontal({ domain = "CurrentPaneDomain" }), p)
        elseif id == "split-v" then win:perform_action(act.SplitVertical({ domain = "CurrentPaneDomain" }), p)
        elseif id == "close" then win:perform_action(act.CloseCurrentPane({ confirm = true }), p)
        elseif id == "tab" then win:perform_action(act.SpawnTab("CurrentPaneDomain"), p)
        elseif id == "op-up" then win:perform_action(adjust_opacity(0.05), p)
        elseif id == "op-down" then win:perform_action(adjust_opacity(-0.05), p)
        elseif id == "blur" then win:perform_action(toggle_blur(), p)
        elseif id == "theme" then win:perform_action(theme_picker(), p)
        elseif id == "zoom0" then win:perform_action(act.ResetFontSize, p)
        elseif id == "reload" then win:perform_action(act.ReloadConfiguration, p)
        end
      end),
    }), pane)
  end)
end

config.keys = {
  -- HELPER: menu con todos los atajos (para no memorizar nada). H = help.
  { key = "h", mods = "CTRL|SHIFT", action = help_menu() },

  -- Paneles (tmux-lite)
  { key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "e", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "LeftArrow",  mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow",    mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow",  mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "r", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
  -- Renombrar la pestana actual: pide el nombre y lo fija (el handler de arriba
  -- lo respeta). Nombre vacio (Enter sin escribir) vuelve al nombre por defecto.
  { key = "n", mods = "CTRL|SHIFT", action = act.PromptInputLine({
    description = "Nuevo nombre de la pestana:",
    action = wezterm.action_callback(function(window, _, line)
      if line ~= nil then window:active_tab():set_title(line) end
    end),
  }) },

  -- PANEL DE CONTROL EN VIVO (teclas simples, sin combinaciones raras):
  { key = "F12", action = adjust_opacity(0.05) },   -- mas opaco
  { key = "F11", action = adjust_opacity(-0.05) },  -- mas transparente
  { key = ".", mods = "CTRL|SHIFT", action = cycle_theme(1) },   -- tema SIGUIENTE (aplica en vivo)
  { key = ",", mods = "CTRL|SHIFT", action = cycle_theme(-1) },  -- tema ANTERIOR (aplica en vivo)
  { key = "b", mods = "CTRL|SHIFT", action = toggle_blur() },      -- blur on/off
  { key = "p", mods = "CTRL|SHIFT", action = theme_picker() },     -- menu de temas (con paleta)
  { key = "0", mods = "CTRL|SHIFT", action = act.ResetFontSize },  -- resetear zoom
}

-- ============================================================================
--  NEOVIM CON ATAJOS DE VS CODE
--  Las terminales no distinguen Ctrl+Shift+letra de Ctrl+letra. Cuando el
--  proceso activo es nvim, estas teclas se mandan en formato CSI-u (que nvim
--  entiende). Fuera de nvim, la tecla hace lo que hacia antes en WezTerm.
-- ============================================================================
local function in_nvim(pane)
  local name = (pane and pane:get_foreground_process_name() or ""):lower()
  return name:find("nvim") ~= nil
end

-- Busca la accion que WezTerm ya tenia para esa tecla (para no pisarla).
local function existing_action(key, mods)
  for _, k in ipairs(config.keys) do
    if k.key == key and k.mods == mods then return k.action end
  end
  return nil
end

local function nvim_key(key, mods, seq, fallback)
  local previous = fallback or existing_action(key, mods) or act.SendKey({ key = key, mods = mods })
  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(window, pane)
      if in_nvim(pane) then
        window:perform_action(act.SendString(seq), pane)
      else
        window:perform_action(previous, pane)
      end
    end),
  }
end

local CSI = "\x1b["
local nvim_keys = {
  -- Ctrl+Shift+letra (mods 6 = ctrl+shift)
  { "p", "CTRL|SHIFT", CSI .. "112;6u" },
  { "f", "CTRL|SHIFT", CSI .. "102;6u", act.Search("CurrentSelectionOrEmptyString") },
  { "e", "CTRL|SHIFT", CSI .. "101;6u" },
  { "g", "CTRL|SHIFT", CSI .. "103;6u" },
  { "o", "CTRL|SHIFT", CSI .. "111;6u" },
  { "r", "CTRL|SHIFT", CSI .. "114;6u" },
  { "m", "CTRL|SHIFT", CSI .. "109;6u", act.Hide },
  { "a", "CTRL|SHIFT", CSI .. "97;6u" },
  { "k", "CTRL|SHIFT", CSI .. "107;6u", act.ClearScrollback("ScrollbackOnly") },
  { "z", "CTRL|SHIFT", CSI .. "122;6u", act.TogglePaneZoomState },
  -- Ctrl+tecla (mods 5 = ctrl) y Ctrl+Alt+K (mods 7)
  { ".", "CTRL", CSI .. "46;5u" },
  { "`", "CTRL", CSI .. "96;5u" },
  { "k", "CTRL|ALT", CSI .. "107;7u" },
  { ",", "CTRL", CSI .. "44;5u" }, -- Ctrl+, settings (Windows / Linux)
  { "h", "CTRL|SHIFT", CSI .. "104;6u" }, -- replace in project
  { "l", "CTRL|SHIFT", CSI .. "108;6u" }, -- select all occurrences
  { "Enter", "CTRL", CSI .. "13;5u" }, -- new line below
  { "Enter", "CTRL|SHIFT", CSI .. "13;6u" }, -- new line above
  { "1", "CTRL", CSI .. "49;5u" }, -- focus editor 1
  { "2", "CTRL", CSI .. "50;5u" }, -- focus editor 2
  { "3", "CTRL", CSI .. "51;5u" }, -- focus editor 3
  { "0", "CTRL", CSI .. "48;5u" }, -- focus explorer
  { "`", "CTRL|SHIFT", CSI .. "96;6u" }, -- new terminal
}

-- macOS: Cmd funciona como en VS Code dentro de nvim (Cmd+P, Cmd+S, Cmd+Shift+P...).
-- Fuera de nvim, Cmd conserva su comportamiento normal de WezTerm.
-- WEZTERM_FORCE_MAC=1 lets the Mac bindings be checked on another OS (wezterm show-keys)
if wezterm.target_triple:find("darwin") or os.getenv("WEZTERM_FORCE_MAC") then
  local cmd_fallback = {
    w = act.CloseCurrentTab({ confirm = true }),
    f = act.Search("CurrentSelectionOrEmptyString"),
    c = act.CopyTo("Clipboard"),
  }
  -- Cmd+letter behaves like Ctrl+letter in nvim (the VS Code shortcuts)
  local cmd_ctrl = {
    p = "\x10", s = "\x13", b = "\x02", w = "\x17", f = "\x06",
    a = "\x01", z = "\x1a", d = "\x04", ["/"] = "\x1f",
    c = "\x03", x = "\x18",
    g = "\x07", l = "\x0c", j = "\x0a", ["\\"] = "\x1c",
  }
  for k, seq in pairs(cmd_ctrl) do
    table.insert(nvim_keys, { k, "CMD", seq, cmd_fallback[k] })
  end
  for _, k in ipairs({ "p", "f", "e", "g", "o", "r", "m", "a", "z", "k", "h", "l" }) do
    table.insert(nvim_keys, { k, "CMD|SHIFT", CSI .. string.byte(k) .. ";6u" })
  end
  table.insert(nvim_keys, { "f", "CMD|ALT", "\x08" }) -- replace in file (VS Code for Mac: Cmd+Option+F)
  table.insert(nvim_keys, { "Enter", "CMD", CSI .. "13;5u" })
  table.insert(nvim_keys, { "Enter", "CMD|SHIFT", CSI .. "13;6u" })
  table.insert(nvim_keys, { "`", "CMD|SHIFT", CSI .. "96;6u" })
  for _, d in ipairs({ "0", "1", "2", "3" }) do
    table.insert(nvim_keys, { d, "CMD", CSI .. string.byte(d) .. ";5u" })
  end
  table.insert(nvim_keys, { ".", "CMD", CSI .. "46;5u" })
  table.insert(nvim_keys, { ",", "CMD", CSI .. "44;5u" }) -- Settings, like VS Code
  table.insert(nvim_keys, { "k", "CMD|ALT", CSI .. "107;7u" }) -- send to Claude
  table.insert(nvim_keys, { "]", "CMD|SHIFT", CSI .. "9;5u" }) -- next tab
  table.insert(nvim_keys, { "[", "CMD|SHIFT", CSI .. "9;6u" }) -- previous tab
  -- macOS text navigation: these work in the shell too, so they are sent everywhere
  local everywhere = {
    { "LeftArrow", "CMD", "\x1b[H" }, -- start of line
    { "RightArrow", "CMD", "\x1b[F" }, -- end of line
    { "UpArrow", "CMD", "\x1b[1;5H" }, -- start of file
    { "DownArrow", "CMD", "\x1b[1;5F" }, -- end of file
    { "Backspace", "CMD", "\x15" }, -- delete to start of line
  }
  for _, k in ipairs(everywhere) do
    table.insert(nvim_keys, { k[1], k[2], k[3], act.SendString(k[3]) })
  end
end

for _, spec in ipairs(nvim_keys) do
  local key, mods, seq, fallback = spec[1], spec[2], spec[3], spec[4]
  local entry = nvim_key(key, mods, seq, fallback)
  local replaced = false
  for i, k in ipairs(config.keys) do
    if k.key == key and k.mods == mods then
      config.keys[i] = entry
      replaced = true
    end
  end
  if not replaced then table.insert(config.keys, entry) end
end

return config
