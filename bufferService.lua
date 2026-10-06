local M = {}
local N = vim.api

--- Opens a scratch buffer in a floating window
--- @return integer buf the buffer id
--- @return integer win the window id
function M.createBuf()
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

--- Returns all buffer lines as one string
--- @param buf integer the buffer id
--- @return string content the buffer content
function M.getBufferContentHasString(buf)
  local contents = N.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(contents)
end

return M
