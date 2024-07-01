local M = {
  'numToStr/Comment.nvim',
  event = 'VeryLazy',
  keys = {
    { 'gc', mode = { 'n', 'v' }, desc = 'Toggle comments' },
    { 'gb', mode = { 'n', 'v' }, desc = 'Toggle block comment' },
  },
}

return M
