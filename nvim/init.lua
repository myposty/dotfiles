-- Lua module cache out of the temp folder (stdpath("cache") is %TEMP%\nvim on Windows):
-- a temp cleaner deleting it while nvim runs made every later module load fail with
-- "ENOENT ... luac". lazy.nvim enables the loader (and creates this folder) next.
vim.loader.path = vim.fn.stdpath("data") .. "/luac"

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
