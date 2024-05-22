local M = {
  {
    'zbirenbaum/copilot.lua',
    event = { 'InsertEnter' },
    cmd = { 'Copilot' },
    opts = {
      suggestion = {
        auto_trigger = true,
      },
    },
  },
}

return M
