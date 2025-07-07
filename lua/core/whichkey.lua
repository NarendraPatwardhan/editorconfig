local M = { -- Useful plugin to show you pending keybinds.
  'folke/which-key.nvim',
  event = 'VimEnter',
  config = function()
    require('which-key').setup()

    -- Document existing key chains. The `group` option is enough
    -- to make these show up in the which-key menu.
    require('which-key').register {
      { '<leader>c', group = '[C]ode' },
      { '<leader>d', group = '[D]ocument' },
      { '<leader>h', group = 'Git [H]unk' },
      { '<leader>r', group = '[R]ename' },
      { '<leader>s', group = '[S]earch' },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>w', group = '[W]orkspace' },
    }

    -- Mappings for specific modes
    require('which-key').register {
      { '<leader>h', desc = 'Git [H]unk', mode = 'v' },
    }
  end,
}

return M
