# AI Chat Performance Design

## Goals

- Reduce database round trips for every AI chat message.
- Keep the chat composer responsive and preserve failed drafts.
- Keep scroll position stable while older messages are prepended.
- Avoid duplicate Premium checks between the Home launcher and chat page.
- Add request-level timing without logging chat content or credentials.

## Backend Flow

`send_message` uses a single `prepare_ai_chat_request` RPC before calling
DeepSeek. The RPC validates Premium access, conversation ownership,
idempotency, daily quota, and loads the latest 12 context messages.

The existing `commit_ai_chat_exchange` RPC remains the only write path. It
acquires a per-user, per-day transaction advisory lock and rechecks the quota
before writing the exchange and usage row. This closes the race where two
devices could both pass a separate preflight count.

`list_ai_chat_messages` combines ownership validation and keyset pagination in
one database call.

## Client Behavior

- A short-lived session cache shares Premium access between the launcher and
  chat page.
- Sending returns success/failure to the composer. Text is cleared only after
  a successful request.
- Loading older messages preserves the current viewport.
- The page scrolls to the bottom only for a new latest message when the user is
  already near the bottom.
- Static page chrome is not rebuilt for every controller notification.

## Telemetry

Each Edge Function request receives a correlation ID. Structured logs contain
only action, status, request ID, stage durations, token counts, and total
duration. Messages, API keys, and authorization headers are never logged.

## Compatibility

Response payloads and action allowlists remain unchanged. Existing stored
conversations continue to work, and expired Premium users can still read or
delete history.
