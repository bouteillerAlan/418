local M = {}
local N = vim.api

--- Opens a scratch buffer in a window and return the id of the window and the id of the buffer
---@return integer, integer
function createBuf()
  local buf = N.nvim_create_buf(false, true)
  N.nvim_set_option_value('buftype', 'acwrite', { buf = buf })

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

--- Main function of the module
function M.quatreCentDixHuit()

  local path = N.nvim_buf_get_name(0)
  local buf, win = createBuf()

  -- inject the path at line 1 and position the cursor at line 2
  N.nvim_buf_set_lines(buf, 0, -1, false, { 'File path:' .. path })
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
      local contents = N.nvim_buf_get_lines(buf, 0, -1, false)
      local prompt = ''
      for _idx, content in ipairs(contents) do
        prompt = prompt .. content
      end
      print('prompt is: ' .. prompt)
    end
  })
end

function M.setup()
  vim.keymap.set("n", "<leader>ppa", M.quatreCentDixHuit, {desc = ""})
end

return M
