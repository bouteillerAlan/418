local M = {}
local N = vim.api
local CurrentBuf = N.nvim_get_current_buf()

--- Opens a scratch buffer in a window and return the id of the window and the id of the buffer
--- @return integer, integer
function createBuf()
  local buf = N.nvim_create_buf(false, true)
  N.nvim_set_option_value('buftype', 'acwrite', { buf = buf })
  N.nvim_buf_set_name(buf, 's-pi-' .. buf)

  local win = N.nvim_open_win(buf, true, {
    relative = 'cursor',
    width = 80,
    height = 4,
    col = 0,
    row = 1,
    anchor = 'NW',
    border = 'rounded',
    title = '418',
    title_pos = 'center',
  })
  return buf, win
end

--- Return the content of a buffer in a string format
--- @param buf integer
--- @return string
function getBufContentHasString(buf)
  local contents = N.nvim_buf_get_lines(buf, 0, -1, false)
  local prompt = ''
  for _, content in ipairs(contents) do
    prompt = prompt .. content
  end
  return prompt
end

--- Main function of the module
function M.quatreCentDixHuit()

  local currentPath = N.nvim_buf_get_name(0)
  local buf, win = createBuf()

  -- inject the path at line 1 and position the cursor at line 2
  N.nvim_buf_set_lines(buf, 0, -1, false, { 'File path:' .. currentPath .. ' ' })
  N.nvim_buf_set_lines(buf, 1, -1, false, { '' } )
  N.nvim_win_set_cursor(win, { 2, 0 })

  -- setup an event for write
  -- group allow to remove the cmd on reload for example
  -- avoiding multiple instance of one cmd
  local group = N.nvim_create_augroup("BufAction", { clear = true })
  N.nvim_create_autocmd('BufWriteCmd', {
    group = group,
    buffer = buf,
    callback = function ()
      N.nvim_set_option_value('modified', false, { buf = buf }) -- this is important, that avoid error when :w
      local content = getBufContentHasString(buf)
      N.nvim_buf_delete(buf, { force = true }) -- bwipeout

      -- run a cmd
      --
      -- to get pi running via rpc
      -- we need first to exec "pi --mode rpc --no-session"
      -- then we need to send a message "{"id": "req-1", "type": "prompt", "message": "Hello, world!"}"
      -- the id there to retrieve the response since all that is async
      -- response is {"id": "req-1", "type": "response", "command": "prompt", "success": true}
      -- error is {"id":"req-3","type":"response","command":"set_model","success":false,"error":"Model not found: invalid/model"}
      --
      -- Hint: vim.system() only returns output after Pi exits, so use
      -- vim.uv.spawn() with stdin/stdout pipes. Write the JSONL prompt to
      -- stdin (... .. "\n"), then read_start() stdout, buffer chunks by
      -- newline, decode each JSON record, and print
      -- message_update.assistantMessageEvent.delta when its type is
      -- text_delta.
      --
      -- To show text directly in the code view, use an extmark with
      -- virtual lines:
      -- - create a namespace with nvim_create_namespace()
      -- - place an extmark at the cursor line with virt_lines
      -- - use virt_lines_above = true to show it above that line
      -- - update the same extmark as streaming deltas arrive
      -- This is display-only; the buffer text remains unchanged.

      vim.system({ "bash", "-c", "pi", "--mode", "rpc", "--no-session" }, { text = true, timeout = 3 },
        function (response)
          if response.code ~= 0 then
            vim.schedule(function () -- mendatory to avoid "nvim_echo must not be called in a fast event context"
              vim.notify(response.stderr, vim.log.levels.ERROR)
            end)
          end
          vim.schedule(function ()
            print(response.stdout)
          end)
        end
      )

      print('prompt is: ' .. content)
    end
  })
end

function M.setup()
  vim.keymap.set("n", "<leader>ppa", M.quatreCentDixHuit, {desc = ""})
end

return M
