require("plugins.418.rpc-types")
local bufferService = require("plugins.418.bufferService")
local validationService = require("plugins.418.validationService")

local M = {}
local N = vim.api
local U = vim.uv

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

--- Main function of the module
function M.quatreCentDixHuit()
  local currentPath = N.nvim_buf_get_name(0)
  local buf, win = bufferService.createBuf()

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
      -- local prompt = bufferService.getBufferContentHasString(buf)
      N.nvim_buf_delete(buf, { force = true }) -- bwipeout

      -- Hint: vim.system() only returns output after Pi exits, so use
      -- vim.U.spawn() with stdin/stdout pipes. Write the JSONL prompt to
      -- stdin (... .. "\n"), then read_start() stdout, buffer chunks by
      -- newline, decode each JSON record, and print
      -- message_update.assistantMessageEvent.delta when its type is
      -- text_delta.

      local prompt = "{\"id\": \"req-1\", \"type\": \"prompt\", \"message\": \"What give 2+2?\"}"
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

      U.write(stdin, prompt .. "\n", function (err)
        if err then
          M.setMarkUnderCursor("Error writing the prompt: " .. tostring(err), "ErrorMsg", true)
          return
        end
      end)

      local dataStreamBuffer = ""
      local isEof = false
      -- create a mark and store all the ids to update it
      local localBuf, nsId, markId, _, rc = unpack(M.setMarkUnderCursor("agent_start", "Comment", false))

      U.read_start(stdout, function(err, dataStream)
        -- note: mandatory to use schedule to avoid executing that in the fast event context and getting an error
        vim.schedule(function()
          if err then
            M.setMarkUnderCursor("Error while reading output stream: " .. tostring(err), "ErrorMsg", true)
            return
          elseif dataStream then

            -- todo:
            --  uv.read_start returns arbitrary stream chunks, not one complete JSON message per callback
            --
            -- Pi RPC writes JSONL, so data can contain:
            -- - half of one JSON object
            -- - multiple JSON objects separated by \n
            -- - a chunk ending midway through a JSON object
            --
            -- vim.json.decode(data) requires exactly one complete JSON value. Therefore it fails when a chunk is
            -- incomplete or combines two JSONL records. You see it twice because the process produced at least
            -- two chunks that were not independently valid JSON
            --
            -- The fix is to keep a stdout buffer, append each data chunk, split complete lines on \n, decode each
            -- complete line, and keep the final unfinished line for the next callback

            -- getting the whole response from rpc stream

            dataStreamBuffer = dataStreamBuffer .. dataStream

            -- check if the last byte value is a LF
            local last_byte = dataStream:byte(-1)
            if last_byte == 10 then
              isEof = true
            end

            if isEof then
              ---@type boolean, PiRpcEvent
              local ok, jsonResponse = pcall(vim.json.decode, dataStream)
              if not ok then
                M.setMarkUnderCursor("Error while decoding response", "ErrorMsg", true)
                return
              end

              local type = jsonResponse.type

              if type == "agent_start" then
                M.updateMark(localBuf, nsId, markId, "agent_start", "Comment", rc, false)
              end

              if type == "turn_start" then
                M.updateMark(localBuf, nsId, markId, "turn_start", "Comment", rc, false)
              end

              if type == "message_update" then
                M.updateMark(localBuf, nsId, markId, "message_update", "Comment", rc, false)
              end

              if type == "turn_end" then
                M.updateMark(localBuf, nsId, markId, "turn_end", "Comment", rc, false)
              end

              isEof = false
              dataStreamBuffer = ""
            end

          end
        end)
      end)

      U.read_start(stderr, function(err, data)
        assert(not err, err)
        if data then
          M.setMarkUnderCursor(data, "ErrorMsg", true)
          return
        else
          -- print("stderr end", stderr)
          -- close
        end
      end)

    end
  })
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
