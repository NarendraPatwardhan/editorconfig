local M = {
  'nvim-lua/plenary.nvim', -- Still optional, but potentially useful
  cmd = { 'Gemini' }, -- Only expose the single combined command
  config = function()
    local api_key = os.getenv 'GEMINI_API_KEY'
    local base_api_url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent'
    local api_url_with_key = base_api_url .. '?key=' .. (api_key or '')

    -- Helper function to display the response (remains the same)
    local function display_response(content)
      if not content or content == '' then
        vim.notify('Gemini returned an empty response or jq failed to extract text.', vim.log.levels.WARN)
        return
      end
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
      vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
      -- The content from jq -r will already have newlines if the original text had them.
      -- vim.split is still useful to turn it into a table of lines for nvim_buf_set_lines.
      local lines = vim.split(content, '\n', { plain = true, trimempty = false }) -- Keep empty lines from text
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
      vim.notify('Gemini response received.', vim.log.levels.INFO)
    end

    -- Function to send the prompt to Gemini
    local function ask_gemini(prompt)
      if not api_key then
        vim.notify('GEMINI_API_KEY environment variable not set.', vim.log.levels.ERROR)
        return
      end
      if not prompt or prompt == '' then
        vim.notify('Prompt cannot be empty.', vim.log.levels.WARN)
        return
      end

      if vim.fn.executable 'jq' == 0 then
        vim.notify('jq command not found. Please install jq.', vim.log.levels.ERROR)
        return
      end

      local data_payload_table = {
        contents = { { parts = { { text = prompt } } } },
        -- generationConfig = { ... } -- Optional
      }
      local data_payload_json = vim.fn.json_encode(data_payload_table)

      -- jq filter to extract the text. Note: array indices are 0-based in jq.
      -- The -r flag outputs raw strings, not JSON-escaped ones.
      local jq_filter = '.candidates[0].content.parts[0].text'

      -- To safely pass data_payload_json which might contain single quotes to a shell command
      -- that itself uses single quotes, we need to escape single quotes within data_payload_json.
      -- ' -> '\'' (close quote, escaped quote, open quote)
      local escaped_data_payload_json = string.gsub(data_payload_json, "'", "'\\''")

      -- Construct the command to pipe curl output to jq
      -- sh -c "curl ... | jq ..."
      local shell_command = string.format(
        "curl -s -X POST -H 'Content-Type: application/json' --data '%s' '%s' | jq -r '%s'",
        escaped_data_payload_json,
        api_url_with_key,
        jq_filter
      )

      local job_cmd = { 'sh', '-c', shell_command }
      local job_output_lines = {}
      local job_stderr_lines = {}

      vim.notify('Sending prompt to Gemini (via curl | jq)...', vim.log.levels.INFO)

      vim.fn.jobstart(job_cmd, {
        -- stdout_buffered = true, -- Not strictly necessary if processing line by line, but fine
        -- stderr_buffered = true,
        on_stdout = function(_, data, _) -- name is not used for on_stdout/on_stderr
          if data then
            for _, line in ipairs(data) do
              if line ~= '' then -- jobstart can send empty strings for final flush
                table.insert(job_output_lines, line)
              end
            end
          end
        end,
        on_stderr = function(_, data, _)
          if data then
            for _, line in ipairs(data) do
              if line ~= '' then
                table.insert(job_stderr_lines, line)
              end
            end
          end
        end,
        on_exit = function(_, exit_code, _)
          vim.schedule(function()
            local job_output = table.concat(job_output_lines, '\n')
            local job_stderr = table.concat(job_stderr_lines, '\n')

            if exit_code ~= 0 then
              local err_msg = 'curl | jq command failed (code ' .. exit_code .. ')'
              if job_stderr ~= '' then
                err_msg = err_msg .. ':\n' .. job_stderr
              end
              if job_output ~= '' and job_output ~= 'null' then -- jq might print error to stdout too
                err_msg = err_msg .. '\nOutput from command:\n' .. job_output
              end
              vim.notify(err_msg, vim.log.levels.ERROR)
              return
            end

            -- If jq -r successfully extracts text, job_output is that text.
            -- If the path doesn't exist, jq -r '.nonexistent.path' outputs 'null' (the string).
            -- If the path is valid but the value is JSON null, jq -r outputs 'null'.
            -- If the input JSON is invalid, jq will error and exit_code will be non-zero.
            if job_output == '' or job_output == 'null' then
              local msg = 'jq could not extract text from Gemini response or response was null/empty.'
              if job_stderr ~= '' then
                msg = msg .. '\nstderr from jq:\n' .. job_stderr
              end
              vim.notify(msg, vim.log.levels.WARN)
              -- For debugging, you might want to see the raw output if jq fails to parse
              -- but that would require another curl call without jq.
              return
            end

            -- job_output is now the extracted text content
            display_response(job_output)
          end)
        end,
      })
    end

    -- Get visual selection text (remains the same)
    local function get_visual_selection()
      if vim.fn.mode():find '[vV\x16]' or vim.fn.line "'<" > 0 then
        local _, start_row, start_col, _ = unpack(vim.fn.getpos "'<")
        local _, end_row, end_col, _ = unpack(vim.fn.getpos "'>")
        if start_row == 0 or end_row == 0 then
          return ''
        end
        local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
        if #lines == 0 then
          return ''
        end
        local start_byte_idx = start_col - 1
        local end_byte_idx = end_col - 1
        if #lines == 1 then
          return vim.fn.strcharpart(lines[1], start_byte_idx, end_byte_idx - start_byte_idx + 1)
        else
          lines[1] = vim.fn.strcharpart(lines[1], start_byte_idx)
          lines[#lines] = vim.fn.strcharpart(lines[#lines], 0, end_byte_idx + 1)
          return table.concat(lines, '\n')
        end
      else
        return ''
      end
    end

    -- Create the single combined user command (remains the same)
    vim.api.nvim_create_user_command('Gemini', function(opts)
      local args = opts.fargs
      local selection = get_visual_selection()
      if #args > 0 then
        ask_gemini(table.concat(args, ' '))
      elseif selection ~= '' then
        vim.ui.input({ prompt = 'Ask Gemini about selection: ', default = 'Explain this ' }, function(input)
          if input then
            local combined_prompt = input .. '\n```\n' .. selection .. '\n```'
            ask_gemini(combined_prompt)
          else
            vim.notify('Gemini request cancelled.', vim.log.levels.INFO)
          end
        end)
      else
        vim.ui.input({ prompt = 'Ask Gemini: ' }, function(input)
          if input then
            ask_gemini(input)
          else
            vim.notify('Gemini request cancelled.', vim.log.levels.INFO)
          end
        end)
      end
    end, {
      nargs = '*',
      range = true,
      desc = 'Ask Google Gemini (uses visual selection if no args provided)',
    })

    print 'Gemini plugin loaded. Use :Gemini command.'
  end,
}

return M
