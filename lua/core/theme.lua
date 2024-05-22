local M = {
  'folke/tokyonight.nvim',
  priority = 1000, -- Make sure to load this before all the other start plugins.
}

function M.init()
  vim.cmd.colorscheme 'tokyonight-night'
  vim.cmd.hi 'Comment gui=none'
end

return M
