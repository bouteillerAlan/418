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


--- Process a rpc event by Pi cmd and update the given mark
---@param jsonResponse PiRpcEvent a full rpc json block, must be validated before
---@param localBuf integer the buffer where the mark are
---@param nsId integer the namespace id of the marks
---@param markId integer the virtual line mark id
---@param rc { [1]: integer, [2]: integer } row and column position
---@return nil
local function processRpcResponse(jsonResponse, localBuf, nsId, markId, rc)
  local eventType = jsonResponse.type
  local message = jsonResponse.message
  local assistantEvent = jsonResponse.assistantMessageEvent
  local toolName = jsonResponse.toolName or "tool"
  local toolArgument = jsonResponse.args and (jsonResponse.args.command or jsonResponse.args.path)

  if eventType == "response" and jsonResponse.success == false then
    M.updateMark(localBuf, nsId, markId, jsonResponse.error or "Pi rejected the request", "ErrorMsg", rc, false)
    return
  end

  if eventType == "agent_start" then
    M.updateMark(localBuf, nsId, markId, "Pi is thinking...", "Comment", rc, false)
  elseif eventType == "message_start" and message and message.role == "assistant" then
    M.updateMark(localBuf, nsId, markId, "Warming up " .. (message.model or "Pi") .. "...", "Comment", rc, false)
  elseif eventType == "message_update" and assistantEvent and assistantEvent.type == "thinking_end" then
    local thinking = assistantEvent.content or "Thinking..."
    -- clean the text, remove all ** and all whitespace characters
    thinking = thinking:gsub("%*", ""):gsub("%s+", " ")
    M.updateMark(localBuf, nsId, markId, thinking, "Comment", rc, false)
  elseif eventType == "tool_execution_start" then
    local detail = type(toolArgument) == "string" and (": " .. toolArgument) or "..."
    M.updateMark(localBuf, nsId, markId, "Calling " .. toolName .. detail, "Comment", rc, false)
  elseif eventType == "tool_execution_end" then
    local status = jsonResponse.isError and "Failed " or "Finished "
    local level = jsonResponse.isError and "ErrorMsg" or "Comment"
    M.updateMark(localBuf, nsId, markId, status .. toolName .. ", thinking...", level, rc, false)
  elseif eventType == "agent_settled" then
    M.updateMark(localBuf, nsId, markId, "Done!", "Comment", rc, true)
  end
end

-- todo: wip
local function processRpcStream(buf)
  N.nvim_set_option_value('modified', false, { buf = buf }) -- this is important, that avoid error when :w
  local userContent = bufferService.getBufferContentHasString(buf)
  N.nvim_buf_delete(buf, { force = true }) -- bwipeout

  local reqId = os.time()
  local prompt = "{\"id\": \"418-req-" .. reqId .. "\", \"type\": \"prompt\", \"message\": \"" .. userContent .. "\"}"
  local cmd = "pi"
  local args = { "--mode", "rpc", "--no-session" }

  local stdin = U.new_pipe()
  local stdout = U.new_pipe()
  local stderr = U.new_pipe()

  -- spawn the process
  local handle, pidOrError = U.spawn(cmd, {
    args = args,
    stdio = { stdin, stdout, stderr }
  }, function(code, signal) -- on exit
    vim.schedule(function ()
      if code ~= 0 then
        M.setMarkUnderCursor("Pi exited with code " .. code .. ", signal " .. signal, "ErrorMsg", true)
      end
    end)
  end)

  if not handle then
    M.setMarkUnderCursor("Could not start Pi: " .. tostring(pidOrError), "ErrorMsg", true)
    return
  end

  -- send the user prompt
  U.write(stdin, prompt .. "\n", function (err)
    if err then
      M.setMarkUnderCursor("Error writing the prompt: " .. tostring(err), "ErrorMsg", true)
      return
    end
  end)

  -- create a mark and store all the ids to update it
  local localBuf, nsId, markId, _, rc = unpack(M.setMarkUnderCursor("Calling Pi...", "Comment", false))

  local incompleteSeg = ""
  local segments = {}

  -- read the stream of data
  -- we use dataStreamBuffer and isEol to detect if a stream is full and execute the rest of the code on it
  -- a "full" dataStream is nothing else that a correct json object with a LF at the end in this case
  U.read_start(stdout, function(err, dataStream)
    -- note: mandatory to use schedule to avoid executing that in the fast event context and getting an error
    vim.schedule(function()
      if err then
        M.setMarkUnderCursor("Error while reading output stream: " .. tostring(err), "ErrorMsg", true)
        return
      end

      if not dataStream then
        M.setMarkUnderCursor("No dataStream.", "ErrorMsg", true)
        return
      end

      -- we consider that a dataStream can be a full json, some part of it, both
      -- so we need to detect each part and act on it
      local start = 1
      while true do
        local findStart, findEnd = dataStream:find("\n", start, true)

        if findStart == nil then
          if incompleteSeg ~= "" then
            incompleteSeg = incompleteSeg .. dataStream
          else
            incompleteSeg = dataStream
          end
          break
        end

        local sub = ""
        if incompleteSeg ~= nil then
          sub = incompleteSeg .. dataStream:sub(start, findStart - 1) -- findStart - 1 for getting }
        else
          sub = incompleteSeg .. dataStream:sub(start, findStart - 1) -- findStart - 1 for getting }
        end
        table.insert(segments, sub)
        start = start + findEnd + 1 -- findEnd + 1 for getting {
        end

        -- print(vim.inspect(segments)) -- todo: were here, with all the segments ok I guess?

        for index, _ in ipairs(segments) do
          local currentSeg = segments[index]
          table.remove(segments, index)
          processRpcResponse(currentSeg, localBuf, nsId, markId, rc)
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
    callback = processRpcStream(buf)
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
