-- Start screen logo: the user's name drawn in the "ANSI Shadow" letter style.
-- The name is stored per machine (not in the repo), asked on the first start,
-- and can be changed any time with :SetName.
local M = {}

local store = vim.fn.stdpath("data") .. "/dotfiles-user.json"

-- stylua: ignore
local font = {
  A = { " █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" },
  B = { "██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██████╔╝", "╚═════╝ " },
  C = { " ██████╗", "██╔════╝", "██║     ", "██║     ", "╚██████╗", " ╚═════╝" },
  D = { "██████╗ ", "██╔══██╗", "██║  ██║", "██║  ██║", "██████╔╝", "╚═════╝ " },
  E = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "███████╗", "╚══════╝" },
  F = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "██║     ", "╚═╝     " },
  G = { " ██████╗ ", "██╔════╝ ", "██║  ███╗", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
  H = { "██╗  ██╗", "██║  ██║", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" },
  I = { "██╗", "██║", "██║", "██║", "██║", "╚═╝" },
  J = { "     ██╗", "     ██║", "     ██║", "██   ██║", "╚█████╔╝", " ╚════╝ " },
  K = { "██╗  ██╗", "██║ ██╔╝", "█████╔╝ ", "██╔═██╗ ", "██║  ██╗", "╚═╝  ╚═╝" },
  L = { "██╗     ", "██║     ", "██║     ", "██║     ", "███████╗", "╚══════╝" },
  M = { "███╗   ███╗", "████╗ ████║", "██╔████╔██║", "██║╚██╔╝██║", "██║ ╚═╝ ██║", "╚═╝     ╚═╝" },
  N = { "███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝" },
  O = { " ██████╗ ", "██╔═══██╗", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
  P = { "██████╗ ", "██╔══██╗", "██████╔╝", "██╔═══╝ ", "██║     ", "╚═╝     " },
  Q = { " ██████╗ ", "██╔═══██╗", "██║   ██║", "██║▄▄ ██║", "╚██████╔╝", " ╚══▀▀═╝ " },
  R = { "██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██║  ██║", "╚═╝  ╚═╝" },
  S = { "███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║", "╚══════╝" },
  T = { "████████╗", "╚══██╔══╝", "   ██║   ", "   ██║   ", "   ██║   ", "   ╚═╝   " },
  U = { "██╗   ██╗", "██║   ██║", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
  V = { "██╗   ██╗", "██║   ██║", "██║   ██║", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚═══╝  " },
  W = { "██╗    ██╗", "██║    ██║", "██║ █╗ ██║", "██║███╗██║", "╚███╔███╔╝", " ╚══╝╚══╝ " },
  X = { "██╗  ██╗", "╚██╗██╔╝", " ╚███╔╝ ", " ██╔██╗ ", "██╔╝ ██╗", "╚═╝  ╚═╝" },
  Y = { "██╗   ██╗", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚██╔╝  ", "   ██║   ", "   ╚═╝   " },
  Z = { "███████╗", "╚══███╔╝", "  ███╔╝ ", " ███╔╝  ", "███████╗", "╚══════╝" },
  [" "] = { "   ", "   ", "   ", "   ", "   ", "   " },
}

local accents = { ["Á"] = "A", ["É"] = "E", ["Í"] = "I", ["Ó"] = "O", ["Ú"] = "U", ["Ü"] = "U", ["Ñ"] = "N" }

local function normalize(name)
  local s = vim.fn.toupper(vim.trim(name or ""))
  for from, to in pairs(accents) do
    s = s:gsub(from, to)
  end
  return (s:gsub("[^A-Z ]", ""):gsub("%s+", " "))
end

local function draw(text)
  local rows = { "", "", "", "", "", "" }
  for ch in text:gmatch(".") do
    local glyph = font[ch]
    for r = 1, 6 do
      rows[r] = rows[r] .. glyph[r]
    end
  end
  return rows
end

function M.get_name()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
  end)
  return ok and type(data) == "table" and data.name or nil
end

function M.set_name(name)
  vim.fn.mkdir(vim.fn.fnamemodify(store, ":h"), "p")
  vim.fn.writefile({ vim.json.encode({ name = name or "" }) }, store)
  pcall(Snacks.dashboard.update)
end

-- Big letters when they fit the window; the first name only if the full one is
-- too wide; plain text as the last resort.
function M.header()
  local name = M.get_name()
  local text = normalize(name ~= nil and name ~= "" and name or "Neovim")
  local max = vim.o.columns - 4
  for _, candidate in ipairs({ text, text:match("^(%S+)") }) do
    local rows = draw(candidate)
    if vim.fn.strdisplaywidth(rows[1]) <= max then
      return table.concat(rows, "\n")
    end
  end
  return text
end

-- first_time: cancelling stores an empty name so the question is not repeated
function M.ask(first_time)
  vim.ui.input({ prompt = "Your name (shown on the start screen): ", default = M.get_name() or "" }, function(input)
    if input ~= nil then
      M.set_name(input)
    elseif first_time == true then
      M.set_name("")
    end
  end)
end

return M
