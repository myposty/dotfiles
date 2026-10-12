-- themes.lua — paletas disponibles. Cada tema define los mismos campos.
-- Para agregar un tema: copia un bloque, cambia los hex, dale un nombre.
-- El tema activo se elige en config.lua -> theme.
-- Ctrl+Shift+P en WezTerm abre el selector de temas en vivo.

return {
  -- ==== Tema propio ========================================================
  ["indigo"] = {
    foreground = "#E4E4EF", background = "#1A1A2A",
    cursor = "#6C6C9E", selection = "#3B3B5C",
    ansi    = { "#2E2E4A", "#9E5C6C", "#6C6C9E", "#8A7A5C", "#4B4B7A", "#7A6C9E", "#565676", "#E4E4EF" },
    brights = { "#3B3B5C", "#b57a8a", "#8a8aba", "#a89a72", "#6c6c9e", "#9a8aba", "#7a7a9a", "#ffffff" },
    tab_active = "#4B4B7A", tab_inactive = "#2E2E4A",
  },

  -- Monokai Dark Soda: fondo oscuro azulado + verde lima, magenta, naranja.
  ["monokai-soda"] = {
    foreground = "#C9C7CD", background = "#191919",
    cursor = "#F92672", selection = "#343434",
    ansi    = { "#1A1A1A", "#F4005F", "#98E024", "#FD971F", "#9D65FF", "#F92672", "#58D1EB", "#C4C5B5" },
    brights = { "#625E4C", "#F4005F", "#98E024", "#E0D561", "#9D65FF", "#F92672", "#58D1EB", "#F6F6EF" },
    tab_active = "#F92672", tab_inactive = "#252525",
  },

  -- ==== Estilo oh-my-posh (colores clasicos de sus temas) ==================
  -- Paradox: el powerline clasico, azul + verde + naranja.
  ["omp-paradox"] = {
    foreground = "#E4E4E4", background = "#0C0C0C",
    cursor = "#00AFFF", selection = "#264F78",
    ansi    = { "#000000", "#C50F1F", "#13A10E", "#C19C00", "#0037DA", "#881798", "#3A96DD", "#CCCCCC" },
    brights = { "#767676", "#E74856", "#16C60C", "#F9F1A5", "#3B78FF", "#B4009E", "#61D6D6", "#F2F2F2" },
    tab_active = "#0037DA", tab_inactive = "#1A1A1A",
  },
  -- Agnoster: el powerline mas famoso, fondo azul oscuro.
  ["omp-agnoster"] = {
    foreground = "#FFFFFF", background = "#1D2733",
    cursor = "#5FAFFF", selection = "#2D3B4D",
    ansi    = { "#1D2733", "#FF5F5F", "#5FD75F", "#D7AF5F", "#5F87D7", "#AF5FD7", "#5FD7D7", "#E4E4E4" },
    brights = { "#4E5A6A", "#FF8787", "#87FF87", "#FFD787", "#87AFFF", "#D787FF", "#87FFFF", "#FFFFFF" },
    tab_active = "#5F87D7", tab_inactive = "#252F3B",
  },
  -- Atomic: oscuro con acentos vivos.
  ["omp-atomic"] = {
    foreground = "#F0F0F0", background = "#151515",
    cursor = "#66CCFF", selection = "#333333",
    ansi    = { "#151515", "#AC4142", "#90A959", "#F4BF75", "#6A9FB5", "#AA759F", "#75B5AA", "#D0D0D0" },
    brights = { "#505050", "#CC6666", "#B5BD68", "#F0C674", "#81A2BE", "#B294BB", "#8ABEB7", "#F5F5F5" },
    tab_active = "#6A9FB5", tab_inactive = "#202020",
  },

  -- ==== Populares ==========================================================
  ["catppuccin"] = {
    foreground = "#CDD6F4", background = "#1E1E2E",
    cursor = "#F5E0DC", selection = "#585B70",
    ansi    = { "#45475A", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#BAC2DE" },
    brights = { "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#A6ADC8" },
    tab_active = "#89B4FA", tab_inactive = "#313244",
  },
  ["catppuccin-latte"] = {  -- version CLARA (fondo claro)
    foreground = "#4C4F69", background = "#EFF1F5",
    cursor = "#DC8A78", selection = "#CCD0DA",
    ansi    = { "#5C5F77", "#D20F39", "#40A02B", "#DF8E1D", "#1E66F5", "#EA76CB", "#179299", "#ACB0BE" },
    brights = { "#6C6F85", "#D20F39", "#40A02B", "#DF8E1D", "#1E66F5", "#EA76CB", "#179299", "#BCC0CC" },
    tab_active = "#1E66F5", tab_inactive = "#DCE0E8",
  },
  ["dracula"] = {
    foreground = "#F8F8F2", background = "#282A36",
    cursor = "#BD93F9", selection = "#44475A",
    ansi    = { "#21222C", "#FF5555", "#50FA7B", "#F1FA8C", "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2" },
    brights = { "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5", "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF" },
    tab_active = "#BD93F9", tab_inactive = "#343746",
  },
  ["tokyo-night"] = {
    foreground = "#C0CAF5", background = "#1A1B26",
    cursor = "#7AA2F7", selection = "#33467C",
    ansi    = { "#15161E", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#A9B1D6" },
    brights = { "#414868", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#C0CAF5" },
    tab_active = "#7AA2F7", tab_inactive = "#24283B",
  },
  ["gruvbox"] = {
    foreground = "#EBDBB2", background = "#282828",
    cursor = "#FE8019", selection = "#504945",
    ansi    = { "#282828", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#A89984" },
    brights = { "#928374", "#FB4934", "#B8BB26", "#FABD2F", "#83A598", "#D3869B", "#8EC07C", "#EBDBB2" },
    tab_active = "#D79921", tab_inactive = "#3C3836",
  },
  ["nord"] = {
    foreground = "#D8DEE9", background = "#2E3440",
    cursor = "#88C0D0", selection = "#434C5E",
    ansi    = { "#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0" },
    brights = { "#4C566A", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#8FBCBB", "#ECEFF4" },
    tab_active = "#81A1C1", tab_inactive = "#3B4252",
  },
  ["rose-pine"] = {
    foreground = "#E0DEF4", background = "#191724",
    cursor = "#EBBCBA", selection = "#403D52",
    ansi    = { "#26233A", "#EB6F92", "#31748F", "#F6C177", "#9CCFD8", "#C4A7E7", "#EBBCBA", "#E0DEF4" },
    brights = { "#6E6A86", "#EB6F92", "#31748F", "#F6C177", "#9CCFD8", "#C4A7E7", "#EBBCBA", "#E0DEF4" },
    tab_active = "#C4A7E7", tab_inactive = "#1F1D2E",
  },
  ["everforest"] = {
    foreground = "#D3C6AA", background = "#2D353B",
    cursor = "#A7C080", selection = "#475258",
    ansi    = { "#343F44", "#E67E80", "#A7C080", "#DBBC7F", "#7FBBB3", "#D699B6", "#83C092", "#D3C6AA" },
    brights = { "#475258", "#E67E80", "#A7C080", "#DBBC7F", "#7FBBB3", "#D699B6", "#83C092", "#D3C6AA" },
    tab_active = "#A7C080", tab_inactive = "#374247",
  },
}
