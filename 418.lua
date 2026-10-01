local M = {}
local N = vim.api
local U = vim.uv

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
      local prompt = getBufContentHasString(buf)
      N.nvim_buf_delete(buf, { force = true }) -- bwipeout

      -- run a cmd
      --
      -- to get pi running via rpc
      -- we need first to exec "pi --mode rpc --no-session" -- todo: put no session behind a settings
      --
      -- then we need to send a message "{"id": "req-1", "type": "prompt", "message": "Hello, world!"}"
      -- the id there is to retrieve the response since all that is async
      -- response is {"id": "req-1", "type": "response", "command": "prompt", "success": true}
      -- error is {"id":"req-3","type":"response","command":"set_model","success":false,"error":"Model not found: invalid/model"}
      --
      -- Hint: vim.system() only returns output after Pi exits, so use
      -- vim.U.spawn() with stdin/stdout pipes. Write the JSONL prompt to
      -- stdin (... .. "\n"), then read_start() stdout, buffer chunks by
      -- newline, decode each JSON record, and print
      -- message_update.assistantMessageEvent.delta when its type is
      -- text_delta.

      local cmd = "pi"
      local args = { "--mode", "rpc", "--no-session" }

      local stdin = U.new_pipe()
      local stdout = U.new_pipe()
      local stderr = U.new_pipe()

      local handle, pid = U.spawn(cmd, {
        args = args,
        stdio = { stdin, stdout, stderr }
      }, function(code, signal) -- on exit
        print(">>> exit:", code, signal)
      end)

      U.read_start(stdout, function(err, data)
        assert(not err, err)
        if data then
          -- print("stdout chunk", stdout, data)

        else
          print("stdout end", stdout)
        end
      end)

      U.read_start(stderr, function(err, data)
        assert(not err, err)
        if data then
          print("stderr chunk", stderr, data)
        else
          print("stderr end", stderr)
        end
      end)

    end
  })
end

-- show text on virtual line
---@param content string
function M.setMarkUnderCursor(content)
  local localBuf = N.nvim_get_current_buf()
  local rid = "418-" .. os.time() -- create a unique name
  local nsId = N.nvim_create_namespace(rid)

  if content == nil or string.len(content) == 0 then
    content = "Pi is thinking..."
  end

  -- row, col
  local cursor = vim.api.nvim_win_get_cursor(0)
  local rc = { cursor[1] - 1, cursor[2] } -- -1 to get the line on top of the current
  if cursor[1] == 1 then -- handle the first line case
    rc[1] = rc[1] + 1
  end

  -- note: we need these kind of message
  -- {{ "Generated output", "Comment" }},
  -- {{ "Warning message", "WarningMsg" }},
  -- {{ "Error message", "ErrorMsg" }},
  local markId = N.nvim_buf_set_extmark(localBuf, nsId, rc[1], rc[2], {
    virt_lines = {
      {{ content, "Comment" }},
    },
    virt_lines_above = true,
  })

  local gutterMarkId = N.nvim_buf_set_extmark(localBuf, nsId, rc[1], rc[2], {
    sign_text = "π",
    sign_hl_group = "DiagnosticInfo",
  })

  vim.defer_fn(function ()
    N.nvim_buf_del_extmark(localBuf, nsId, markId)
    N.nvim_buf_del_extmark(localBuf, nsId, gutterMarkId)
  end, 3000)
end

function M.setup()
  vim.keymap.set("n", "<leader>ppa", M.quatreCentDixHuit, { desc = "" })
end

return {
  name = "418",
  dir = vim.fn.stdpath("config"),
  config = function()
    M.setup()
  end,
}
