local M = {
  'nvim-lua/plenary.nvim', -- Still optional, but potentially useful
  cmd = { 'Gemini' }, -- Only expose the single combined command
  config = function()
    local api_key = os.getenv 'GEMINI_API_KEY'
    local api_url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=' .. (api_key or '')

    -- Helper function to display the response (remains the same)
    local function display_response(content)
      if not content or content == '' then
        vim.notify('Gemini returned an empty response.', vim.log.levels.WARN)
        return
      end
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
      vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
      local lines = vim.split(content, '\n')
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      local width = math.floor(vim.o.columns * 0.8)
      local height = math.min(#lines + 4, math.floor(vim.o.lines * 0.6))
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)
      vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
      })
      vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
      vim.notify('Gemini response received. Press "q" in the floating window to close.', vim.log.levels.INFO)
    end

    -- Function to send the prompt to Gemini (remains the same)
    local function ask_gemini(prompt)
      if not api_key then
        vim.notify('GEMINI_API_KEY environment variable not set.', vim.log.levels.ERROR)
        return
      end
      if not prompt or prompt == '' then
        vim.notify('Prompt cannot be empty.', vim.log.levels.WARN)
        return
      end
      local data_payload = vim.fn.json_encode {
        contents = { { parts = { { text = prompt } } } },
        -- generationConfig = { ... } -- Optional
      }
      local curl_cmd = { 'curl', '-s', '-X', 'POST', '-H', 'Content-Type: application/json', '--data', data_payload, api_url }
      local job_output = ''
      local job_stderr = ''
      vim.notify('Sending prompt to Gemini...', vim.log.levels.INFO)
      vim.fn.jobstart(curl_cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          if data then
            job_output = table.concat(data, '\n')
          end
        end,
        on_stderr = function(_, data)
          if data then
            job_stderr = table.concat(data, '\n')
          end
        end,
        on_exit = function(_, exit_code)
          vim.schedule(function()
            if exit_code ~= 0 then
              vim.notify('curl command failed (code ' .. exit_code .. '):\n' .. job_stderr, vim.log.levels.ERROR)
              return
            end
            local ok, result = pcall(vim.fn.json_decode, job_output)
            if not ok or not result then
              vim.notify('Failed to decode JSON response from Gemini:\n' .. job_output, vim.log.levels.ERROR)
              return
            end
            -- ADJUST THIS PATH based on actual API response structure
            local response_text = result
              and result.candidates
              and result.candidates[1]
              and result.candidates[1].content
              and result.candidates[1].content.parts
              and result.candidates[1].content.parts[1]
              and result.candidates[1].content.parts[1].text
            if response_text then
              display_response(response_text)
            else
              vim.notify('Could not extract text from Gemini response structure:\n' .. job_output, vim.log.levels.ERROR)
              print 'Full Gemini Response:'
              print(vim.inspect(result)) -- Use vim.inspect for better table printing
            end
          end)
        end,
      })
    end

    -- Get visual selection text (remains the same)
    local function get_visual_selection()
      -- Check if visual mode is active or if '< and '> marks are set
      if vim.fn.mode():find '[vV\x16]' or vim.fn.line "'<" > 0 then
        local _, start_row, start_col, _ = unpack(vim.fn.getpos "'<")
        local _, end_row, end_col, _ = unpack(vim.fn.getpos "'>")
        if start_row == 0 or end_row == 0 then
          return ''
        end -- Should not happen if mode is visual, but safety check

        local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
        if #lines == 0 then
          return ''
        end

        -- Adjust start/end col for multiline selection (getpos gives byte index)
        -- Using byteidx accurately gets the character position from byte offset
        local start_byte_idx = start_col - 1
        local end_byte_idx = end_col - 1

        if #lines == 1 then
          -- Extract substring based on byte indices
          return vim.fn.strcharpart(lines[1], start_byte_idx, end_byte_idx - start_byte_idx + 1)
        else
          -- Extract relevant parts from first and last lines based on byte indices
          lines[1] = vim.fn.strcharpart(lines[1], start_byte_idx)
          lines[#lines] = vim.fn.strcharpart(lines[#lines], 0, end_byte_idx + 1)
          return table.concat(lines, '\n')
        end
      else
        return '' -- Not in visual mode and no previous selection marks
      end
    end

    -- Create the single combined user command
    vim.api.nvim_create_user_command('Gemini', function(opts)
      local args = opts.fargs -- Arguments passed to the command
      local selection = get_visual_selection()

      if #args > 0 then
        -- Case 1: Arguments provided - use args as the prompt
        -- We prioritize arguments over visual selection for simplicity.
        -- If you wanted to combine them, you'd add logic here.
        ask_gemini(table.concat(args, ' '))
      elseif selection ~= '' then
        -- Case 2: No arguments, but text is selected - prompt about the selection
        vim.ui.input({ prompt = 'Ask Gemini about selection: ', default = 'Explain this: ' }, function(input)
          if input then
            -- Combine the user's prompt with the selection (wrapped in code fences)
            local combined_prompt = input .. '\n```\n' .. selection .. '\n```'
            ask_gemini(combined_prompt)
          else
            vim.notify('Gemini request cancelled.', vim.log.levels.INFO)
          end
        end)
      else
        -- Case 3: No arguments and no selection - prompt for a general question
        vim.ui.input({ prompt = 'Ask Gemini: ' }, function(input)
          if input then
            ask_gemini(input)
          else
            vim.notify('Gemini request cancelled.', vim.log.levels.INFO)
          end
        end)
      end
    end, {
      nargs = '*', -- Allow zero or more arguments
      range = true, -- Allows '< and '> marks to be set correctly when called after visual selection
      desc = 'Ask Google Gemini (uses visual selection if no args provided)',
    })

    print 'Gemini plugin loaded. Use the combined :Gemini command.'
  end,
}

return M
