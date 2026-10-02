# Pi RPC event format

Notes on the JSONL records pi emits in `--mode rpc`, for reference when parsing
`rpc-output.jsonl` / writing the handler in `418.lua`. Source: pi's own docs
(`docs/rpc.md`, `docs/json.md`, `docs/message-types.md`).

## Command ack

- `response` — reply to a command we sent, matched by `id`.
  - `success: true/false`
  - `data` on success, `error` string on failure
  - `command` names which command it answers (e.g. `"prompt"`)
  - a `prompt` success only means accepted/queued (`data.disposition`:
    `"started"` / `"handled"` / ...) — not that the model finished
  - malformed JSON we sent back gets a `response` with `command:"parse"` and no `id`

## Run / turn lifecycle

- `agent_start` — a low-level agent run started
- `turn_start` — one assistant turn started
- `turn_end` — `message` (final assistant message for the turn) + `toolResults`
- `agent_end` — `messages`, `willRetry` — this run ended, but retries/compaction/
  follow-ups may still continue
- `agent_settled` — pi has nothing left to do automatically; the real
  "conversation is done" signal

## Message streaming

- `message_start` / `message_end` — full message lifecycle
  (`message.role`: `system` / `user` / `assistant`); `message_end` is authoritative
- `message_update` — delta only, via `assistantMessageEvent.type`:
  - `text_start` / `text_delta` (`delta`) / `text_end` (`content`)
  - `thinking_start` / `thinking_delta` / `thinking_end`
  - `toolcall_start` (`id`, `toolName`) / `toolcall_delta` (raw arg json
    fragments) / `toolcall_end` (`toolCall` = `{id, name, arguments}`)
  - `done` / `error` — provider stream finished/errored (normally folded into
    `message_start`/`message_end` instead of appearing directly)

## Tool execution (the tool actually running, not just the model deciding to call it)

- `tool_execution_start` — `toolCallId`, `toolName`, `args`
- `tool_execution_update` — `partialResult`
- `tool_execution_end` — `result`, `isError`

## Errors

- `response` with `success:false` + `error`
- `message_update` → `assistantMessageEvent.type === "error"`
- `extension_error` — `extensionPath`, `event`, `error`

## Misc / less common

- `queue_update`, `entry_appended`, `session_info_changed`, `thinking_level_changed`
- `compaction_start` / `compaction_end`
- `auto_retry_start` / `auto_retry_end`, `summarization_retry_*`
- `bash_execution_update` — only for a direct RPC `bash` command, streams
  output chunks tagged with that command's `id`

## What `rpc-output.jsonl` actually shows

Only the trivial path, no tool call / error / retry:

```
response(prompt) -> agent_start -> turn_start -> message_start(assistant, pending)
  -> message_update(text_delta) x N -> message_end(final text) -> turn_end
  -> agent_end -> agent_settled
```
