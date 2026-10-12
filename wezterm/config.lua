-- ============================================================================
--  config.lua — PANEL DE CONFIGURACION. El UNICO archivo que necesitas tocar.
--  Cambia un valor, guarda, y en WezTerm apreta Ctrl+Shift+R para recargar.
--
--  Tambien podes cambiar cosas EN VIVO con el teclado (ver ATAJOS abajo):
--    Alt+Shift+Arriba/Abajo = opacidad   |   Ctrl+Shift+B = blur on/off
--    Ctrl+Shift+P = menu de temas        |   Ctrl+Shift+0 = resetear zoom
-- ============================================================================

return {
  -- ==== TEMA ================================================================
  -- Opciones (12):
  --   "indigo"           el tema propio (indigo mate)
  --   "omp-paradox"      estilo oh-my-posh Paradox (azul/verde/naranja)
  --   "omp-agnoster"     estilo oh-my-posh Agnoster (azul oscuro)
  --   "omp-atomic"       estilo oh-my-posh Atomic
  --   "catppuccin"       pastel oscuro
  --   "catppuccin-latte" pastel CLARO (fondo claro)
  --   "dracula"          violeta/rosa clasico
  --   "tokyo-night"      azul profundo
  --   "gruvbox"          calido retro
  --   "nord"             azul frio nordico
  --   "rose-pine"        malva elegante
  --   "everforest"       verde bosque
  theme = "indigo",

  -- ==== FONDO (blur / transparencia) ========================================
  -- opacity: 1.0 = solido | 0.7 = translucido | 0.5 = bien transparente.
  opacity = 0.70,
  -- Blur del fondo en Windows 11: "Acrylic" (fuerte) | "Mica" (sutil) | "Disable".
  -- Requiere WezTerm nightly; en versiones viejas se ignora.
  win_backdrop = "Acrylic",
  -- Blur en macOS: 0 (nada) a 30 (fuerte).
  mac_blur = 20,

  -- ==== FUENTE ==============================================================
  -- Cualquier fuente instalada. Para iconos, usa una Nerd Font.
  -- Ideas: "CaskaydiaCove Nerd Font", "JetBrainsMono Nerd Font", "FiraCode Nerd Font"
  font = "CaskaydiaCove Nerd Font",
  font_size = 12.0,        -- tamano en puntos
  line_height = 1.1,       -- alto de linea (1.0 = pegado, 1.2 = aireado)
  -- Ligaduras de fuente (>= => ->). true si tu fuente las tiene (FiraCode, JetBrains).
  font_ligatures = false,

  -- ==== VENTANA =============================================================
  window_buttons = true,       -- botones minimizar/maximizar/cerrar
  tabs_at_bottom = true,       -- barra de pestanas abajo (false = arriba)
  hide_tabs_when_single = true,-- ocultar pestanas si hay una sola
  padding = 10,                -- espacio interno en pixeles

  -- ==== COMPORTAMIENTO ======================================================
  confirm_close = true,        -- preguntar al cerrar si hay un proceso corriendo
  scrollback_lines = 10000,    -- cuantas lineas de historial guarda la terminal

  -- ==== IDIOMA ==============================================================
  -- Idioma de los textos de la UI (ej. el dialogo de "cerrar ventana?").
  -- "es" = espanol | "en" = ingles | "auto" = detectar del sistema.
  language = "es",

  -- ==== SHELL (Windows) =====================================================
  -- Ruta al shell. En Windows: Git Bash. En Mac/Linux: dejalo en nil.
  windows_shell = "C:/Program Files/Git/bin/bash.exe",
}

-- ============================================================================
--  ATAJOS DE TECLADO (para referencia; se definen en wezterm.lua)
-- ----------------------------------------------------------------------------
--  EN VIVO:
--    Alt+Shift+Arriba    subir opacidad (mas solido)
--    Alt+Shift+Abajo     bajar opacidad (mas transparente)
--    Ctrl+Shift+B        blur ON/OFF
--    Ctrl+Shift+P        menu para elegir tema
--    Ctrl+Shift+0        resetear zoom de fuente
--    Ctrl+Shift+R        recargar config.lua
--  PANELES:
--    Ctrl+Shift+D        dividir horizontal
--    Ctrl+Shift+E        dividir vertical
--    Ctrl+Shift+Flechas  moverse entre paneles
--    Ctrl+Shift+W        cerrar panel
--    Ctrl+Shift+T        nueva pestana
-- ============================================================================
