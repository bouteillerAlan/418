require("plugins.418.rpc-types")
local bufferService = require("plugins.418.bufferService")
local markService = require("plugins.418.markService")

local M = {}
local N = vim.api
local U = vim.uv

-- todo: handle the multi edit case (multi agent and user in the same file)
-- todo: put --no-session in a setting

-- flag to avoid sending same message multiple time for nothing
-- this is 100% for UX
local warmUp = true

--- Process a rpc event by Pi cmd and update the given mark
---@param jsonResponse PiRpcEvent a full rpc json block, must be validated before
---@param localBuf integer the buffer where the mark are
---@param nsId integer the namespace id of the marks
---@param markId integer the virtual line mark id
---@param gutMarkId integer the gutter mark id
---@param rc { [1]: integer, [2]: integer } row and column position
---@return nil
local function processRpcResponse(jsonResponse, localBuf, nsId, markId, gutMarkId, rc)
  local eventType = jsonResponse.type
  local message = jsonResponse.message
  local assistantEvent = jsonResponse.assistantMessageEvent
  local toolName = jsonResponse.toolName or "tool"
  local toolArgument = jsonResponse.args and (jsonResponse.args.command or jsonResponse.args.path)

  if eventType == "response" and jsonResponse.success == false then
    markService.updateMark(localBuf, nsId, markId, jsonResponse.error or "Pi rejected the request", "ErrorMsg", rc, false)
    return
  end

  if eventType == "agent_start" then
    markService.updateMark(localBuf, nsId, markId, "Pi is thinking...", "Comment", rc, false)
  elseif eventType == "message_start" and message and message.role == "assistant" then
    if warmUp then
      markService.updateMark(localBuf, nsId, markId, "Warming up " .. (message.model or "Pi") .. "...", "Comment", rc, false)
      warmUp = false
    end
  elseif eventType == "message_update" and assistantEvent and assistantEvent.type == "thinking_end" then
    local thinking = assistantEvent.content or "Thinking..."
    -- clean the text, remove all ** and all whitespace characters
    thinking = thinking:gsub("%*", ""):gsub("%s+", " ")
    markService.updateMark(localBuf, nsId, markId, thinking, "Comment", rc, false)
  elseif eventType == "tool_execution_start" then
    local detail = type(toolArgument) == "string" and (": " .. toolArgument) or "..."
    markService.updateMark(localBuf, nsId, markId, "Calling " .. toolName .. detail, "Comment", rc, false)
  elseif eventType == "tool_execution_end" then
    local status = jsonResponse.isError and "Failed " or "Finished "
    local level = jsonResponse.isError and "ErrorMsg" or "Comment"
    markService.updateMark(localBuf, nsId, markId, status .. toolName .. ", thinking...", level, rc, false)
  elseif eventType == "agent_settled" then
    markService.updateMark(localBuf, nsId, markId, "Done!", "Comment", rc, false)
    vim.defer_fn(function ()
      markService.removeMark(localBuf, nsId, { markId, gutMarkId })
    end, 5000)
  end
end

--- Send the prompt buffer content to Pi and process its RPC response stream
---@param buf integer prompt buffer handle
---@param userData string current path and line of the user prompt formatted
---@return nil
local function startAndProcessRpcStream(buf, userData)
  N.nvim_set_option_value('modified', false, { buf = buf }) -- this is important, that avoid error when :w
  local userContent = bufferService.getBufferContentHasString(buf)
  N.nvim_buf_delete(buf, { force = true }) -- bwipeout

  local composedPrompt = userData .. " " .. userContent

  local reqId = os.time()
  local prompt = "{\"id\": \"418-req-" .. reqId .. "\", \"type\": \"prompt\", \"message\": \"" .. composedPrompt .. "\"}"
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
        markService.setMarkUnderCursor("Pi exited with code " .. code .. ", signal " .. signal, "ErrorMsg", true)
      end
    end)
  end)

  if not handle then
    markService.setMarkUnderCursor("Could not start Pi: " .. tostring(pidOrError), "ErrorMsg", true)
    return
  end

  -- send the user prompt
  U.write(stdin, prompt .. "\n", function (err)
    if err then
      markService.setMarkUnderCursor("Error writing the prompt: " .. tostring(err), "ErrorMsg", true)
      return
    end
  end)

  -- create a mark and store all the ids to update it
  local localBuf, nsId, markId, gutMarkId, rc = unpack(markService.setMarkUnderCursor("Calling Pi...", "Comment", false))

  local incompleteSeg = ""
  local segments = {}
  local idx = 1

  -- read the stream of data
  -- we use dataStreamBuffer and isEol to detect if a stream is full and execute the rest of the code on it
  -- a "full" dataStream is nothing else that a correct json object with a LF at the end in this case
  U.read_start(stdout, function(err, dataStream)
    -- note: mandatory to use schedule to avoid executing that in the fast event context and getting an error
    vim.schedule(function()
      if err then
        markService.setMarkUnderCursor("Error while reading output stream: " .. tostring(err), "ErrorMsg", true)
        return
      end

      if not dataStream then
        markService.setMarkUnderCursor("No dataStream.", "ErrorMsg", true)
        return
      end

      -- we consider that a dataStream can be a full json, some part of it or both
      -- so we need to detect each part "type" and act on it
      local cursor = 1
      while true do
        -- end of string exit
        -- this is not char perfect but since we "cut" on the find this is perfectly fine
        if cursor > dataStream:len() then
          break
        end

        -- note: dont forget that in find if we search for "x" both position are
        -- going to be the same value, don't loose hours like me 🤡
        local _, findEnd = dataStream:find("\n", cursor, true)

        -- we found no \n so the whole segment is a part and not a full good segment
        if findEnd == nil then
          -- since an empty incompleteSeg is empty anyway we can
          -- prepend it event when it contain nothing, this just avoid some line
          -- of code for a if else
          incompleteSeg = incompleteSeg .. dataStream:sub(cursor)
          -- since we found nothing no search is needed anymore
          break
        end

        local subText = ""
        -- same has before, empty is empty so ... :)
        subText = incompleteSeg .. dataStream:sub(cursor, findEnd)
        incompleteSeg = ""

        subText = string.gsub(subText, "\n", "")
        table.insert(segments, subText) -- remove the leading "\n"
        cursor = findEnd + 1 -- move the cursor to search the next segment
      end -- while

      -- for each json segment process the response
      while true do
        local gSub = string.gsub(segments[idx], "\0", "") -- remove null byte at the end

        local currentSeg = vim.json.decode(gSub)
        processRpcResponse(currentSeg, localBuf, nsId, markId, gutMarkId, rc)
        if idx == #segments then
          break
        end
        idx = idx + 1
      end

    end) -- vim.schedule
  end) -- read_start

  U.read_start(stderr, function(err, data)
    assert(not err, err)
    if data then
      markService.setMarkUnderCursor(data, "ErrorMsg", true)
      return
    else
      print("stderr end", stderr)
      -- close
    end
  end)

end

--- Main function of the module
function M.quatreCentDixHuit()
  -- get the current path, line and column
  local path = N.nvim_buf_get_name(0)
  local line, column = unpack(N.nvim_win_get_cursor(0))
  local userData = "User is on line " .. line .. " of file " .. path .. ", if not stated otherwise or logically wrong you should respond on this line and file."

  local buf, win = bufferService.createBuf()

  -- inject the path at line 1 and position the cursor at line 2
  -- N.nvim_buf_set_lines(buf, 0, -1, false, { 'File path:' .. path .. ' ' })
  -- N.nvim_buf_set_lines(buf, 1, -1, false, { '' } )
  N.nvim_win_set_cursor(win, { 1, 0 })

  -- setup an event for write
  -- group allow to remove the cmd on reload for example
  -- avoiding multiple instance of one cmd
  local group = N.nvim_create_augroup("BufAction", { clear = true })
  N.nvim_create_autocmd('BufWriteCmd', {
    group = group,
    buffer = buf,
    callback = function (event)
      startAndProcessRpcStream(event.buf, userData)
    end,
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
