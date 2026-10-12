local validationService = require("plugins.418.validationService")

local M = {}
local N = vim.api

---@alias markDataType { [1]: integer, [2]: integer, [3]: integer, [4]: integer, [5]: { [1]: integer, [2]: integer } }

--- Shows text on a virtual line
--- Text is show on top of the cursor line except for line 1 where the text is below
---@param content string the content you want to be shown
---@param level "Comment" | "WarningMsg" | "ErrorMsg" the type of the message, change the color and style of the text
---@param autoClose boolean if true the mark auto remove itself after 10s
---@return markDataType markData return all the data needed to update or remove the mark later, in order: localBuf, nsId, markId, gutterMarkId, rc
function M.setMarkUnderCursor(content, level, autoClose)
  validationService.validateString(content, "content", true)
  validationService.validateString(level, "level", true)
  validationService.validateBoolean(autoClose, "autoClose", true)
  validationService.validateOneOf(level, "level", { "Comment", "WarningMsg", "ErrorMsg" })

  if content == nil or string.len(content) == 0 then
    content = "Pi is thinking..."
  end

  if level == nil or string.len(level) == 0 then
    level = "Comment"
  end

  if autoClose == nil then
    autoClose = false
  end

  local localBuf = N.nvim_get_current_buf()
  local rid = "418-" .. os.time() -- create a unique name to avoid conflict
  local nsId = N.nvim_create_namespace(rid)

  -- row, col
  local cursor = N.nvim_win_get_cursor(0)
  local rc = { cursor[1] - 1, cursor[2] } -- -1 to get the line on top of the current
  if cursor[1] == 1 then -- handle the first line case
    rc[1] = rc[1] + 1
  end

  -- note: we need these kind of message
  -- {{ "Generated output", "Comment" }},
  -- {{ "Warning message", "WarningMsg" }},
  -- {{ "Error message", "ErrorMsg" }},
  local markId = N.nvim_buf_set_extmark(localBuf, nsId, rc[1], rc[2], {
    virt_lines = {{{ content, level }}},
    virt_lines_above = true,
  })

  local gutterMarkId = N.nvim_buf_set_extmark(localBuf, nsId, rc[1], rc[2], {
    sign_text = "π",
    sign_hl_group = level,
  })

  if autoClose then
    vim.defer_fn(function()
      M.removeMark(localBuf, nsId, { markId, gutterMarkId })
    end, 10000)
  end

  return { localBuf, nsId, markId, gutterMarkId, rc }
end

--- Update an extmarks content from a buffer
---@param localBuf integer the buffer containing the marks
---@param nsId integer the namespace id of the marks
---@param markId integer the virtual line mark id
---@param content string the content you want to be shown
---@param level "Comment" | "WarningMsg" | "ErrorMsg" the type of the message, change the color and style of the text
---@param rc { [1]: integer, [2]: integer } row and column position
---@param autoClose boolean auto close the mark after 10 seconds, this doesn't remove automatically the gutter symbol that is another mark
---@return nil
function M.updateMark(localBuf, nsId, markId, content, level, rc, autoClose)
  validationService.validateInt(localBuf, "localBuf")
  validationService.validateInt(nsId, "nsId")
  validationService.validateInt(markId, "markId")
  validationService.validateString(content, "content", true)
  validationService.validateString(level, "level", true)
  validationService.validateBoolean(autoClose, "autoClose", true)
  validationService.validateTable(rc, "rc")
  validationService.validateNonNegativeInt(rc[1], "rc row")
  validationService.validateNonNegativeInt(rc[2], "rc column")
  validationService.validateOneOf(level, "level", { "Comment", "WarningMsg", "ErrorMsg" })

  if content == nil or string.len(content) == 0 then
    content = "Pi is thinking..."
  end

  if level == nil or string.len(level) == 0 then
    level = "Comment"
  end

  if autoClose == nil then
    autoClose = false
  end

  N.nvim_buf_set_extmark(localBuf, nsId, rc[1], rc[2], {
    id = markId,
    virt_lines = {{{ content, level }}},
    virt_lines_above = true,
  })

  if autoClose then
    vim.defer_fn(function()
      M.removeMark(localBuf, nsId, { markId })
    end, 10000)
  end
end

--- Removes extmarks from a buffer
---@param localBuf integer the buffer where the mark are
---@param nsId integer the group id of the mark
---@param ids integer[] the mark id's you want to remove
---@return nil
function M.removeMark(localBuf, nsId, ids)
  validationService.validateInt(localBuf, "localBuf")
  validationService.validateInt(nsId, "nsId")
  validationService.validateTable(ids, "ids")

  for _, id in ipairs(ids) do
    N.nvim_buf_del_extmark(localBuf, nsId, id)
  end
end

return M
