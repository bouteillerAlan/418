---@alias PiRpcEventType
---| "response"
---| "agent_start"
---| "turn_start"
---| "turn_end"
---| "agent_end"
---| "agent_settled"
---| "message_start"
---| "message_update"
---| "message_end"
---| "tool_execution_start"
---| "tool_execution_update"
---| "tool_execution_end"
---| "extension_error"
---| "queue_update"
---| "entry_appended"
---| "session_info_changed"
---| "thinking_level_changed"
---| "compaction_start"
---| "compaction_end"
---| "auto_retry_start"
---| "auto_retry_end"
---| "summarization_retry_start"
---| "summarization_retry_end"
---| "bash_execution_update"

---@alias PiAssistantMessageEventType
---| "text_start"
---| "text_delta"
---| "text_end"
---| "thinking_start"
---| "thinking_delta"
---| "thinking_end"
---| "toolcall_start"
---| "toolcall_delta"
---| "toolcall_end"
---| "done"
---| "error"

---@class PiRpcTextContent
---@field type string Content block type
---@field text? string Text in a final assistant message

---@class PiRpcMessage
---@field role "system"|"user"|"assistant" Message author
---@field content PiRpcTextContent[] Message content blocks

---@class PiRpcToolCall
---@field id string Tool call identifier
---@field name string Tool name
---@field arguments table Tool arguments

---@class PiRpcAssistantMessageEvent
---@field type PiAssistantMessageEventType Stream update category
---@field delta? string Text, thinking, or raw tool argument fragment
---@field content? string Completed text content
---@field id? string Tool call identifier
---@field toolName? string Tool name before the call completes
---@field toolCall? PiRpcToolCall Completed tool call
---@field error? string Provider stream error

---@class PiRpcToolResult
---@field toolCallId? string Tool call identifier
---@field result? unknown Tool result
---@field isError? boolean Whether the result is an error

---@class PiRpcResponseData
---@field disposition? "started"|"handled" Prompt acceptance state

---@class PiRpcEvent
---@field type PiRpcEventType Event category
---@field id? string RPC command identifier
---@field command? string Command answered by a response event
---@field success? boolean Whether a response command succeeded
---@field data? PiRpcResponseData Response payload
---@field error? string Command, stream, or extension error
---@field message? PiRpcMessage Final turn message or message lifecycle payload
---@field messages? PiRpcMessage[] Messages produced by an agent run
---@field toolResults? PiRpcToolResult[] Results from tools run during a turn
---@field willRetry? boolean Whether pi will retry after an agent run
---@field assistantMessageEvent? PiRpcAssistantMessageEvent Assistant stream delta
---@field toolCallId? string Identifier for an executing tool call
---@field toolName? string Name of an executing tool
---@field args? table Arguments passed to an executing tool
---@field partialResult? unknown Partial result from a running tool
---@field result? unknown Final tool result
---@field isError? boolean Whether a tool result is an error
---@field extensionPath? string Extension that emitted an error
---@field event? string Extension event that failed

---@class PiRpcTypes
local M = {}

return M
