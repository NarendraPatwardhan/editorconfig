local M = {
  'catppuccin/nvim',
  name = 'catppuccin',
  flavor = 'mocha',
  priority = 1000,
}

function M.init()
  vim.cmd.colorscheme 'catppuccin'
end

return M
