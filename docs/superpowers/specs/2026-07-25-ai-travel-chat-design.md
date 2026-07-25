# AI Travel Chat Design

## Goal

Add a Premium-only AI travel assistant that can answer a user's question,
suggest an existing app feature, and navigate only after the user explicitly
presses the suggested action button.

The feature must:

- Use DeepSeek for chat responses.
- Use Vbee for text-to-speech only when the user presses a speaker button.
- Store conversation history in Supabase per user.
- Expose a draggable floating entry point on Home.
- Remain visible to free users with a lock badge and direct them to Upgrade
  Account.
- Enforce Premium access and a configurable limit of 100 sent messages per day
  on the backend.

## Non-goals

- The first version does not stream tokens from DeepSeek.
- The assistant does not execute destructive operations.
- The assistant does not navigate automatically.
- The assistant cannot open arbitrary URLs or arbitrary application routes.
- Generated Vbee audio is not persisted in Supabase or R2.

## Chosen Architecture

Use a dedicated Supabase Edge Function named `ai-chat`.

```text
Flutter AI Chat
    -> ai-chat Edge Function
        -> JWT and Premium validation
        -> daily quota and idempotency validation
        -> recent conversation context
        -> DeepSeek chat completion
        -> response and navigation-action validation
        -> Supabase conversation history

Flutter speaker action
    -> ai-chat TTS action
        -> JWT and Premium validation
        -> shared Vbee TTS integration
        -> temporary audio URL
```

DeepSeek and Vbee credentials remain in Supabase Secrets. Flutter never receives
provider API keys.

The dedicated function keeps conversation, Premium, quota, and navigation logic
separate from the existing generic AI gateway. Shared provider helpers may be
extracted into `_shared` modules when this avoids duplicating the existing Vbee
integration.

## Data Model

### `ai_chat_conversation`

- `id_conversation uuid primary key`
- `id_user uuid not null references user_account(id_user) on delete cascade`
- `title text not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

The first user message is used to generate a short title. Conversations are
listed newest-first by `updated_at`.

### `ai_chat_message`

- `id_message uuid primary key`
- `id_conversation uuid not null references ai_chat_conversation on delete
  cascade`
- `role text not null`, restricted to `user` and `assistant`
- `content text not null`
- `action_key text null`
- `action_payload jsonb null`
- `request_id uuid null`
- `created_at timestamptz not null`

A partial unique index on `(id_conversation, request_id)` prevents duplicate
user messages when the client retries a request. Assistant messages do not need
a request ID.

Indexes support:

- Conversation lookup by user and `updated_at`.
- Message lookup by conversation and `created_at`.
- Idempotent lookup by conversation and request ID.

RLS permits a user to read and delete only conversations they own and messages
belonging to those conversations. The Edge Function also validates JWT identity
and ownership before using its service-role client.

Deleting a conversation cascades to all of its messages.

A database RPC commits the user message, assistant message, conversation
timestamp, and usage entry atomically. A failed commit therefore cannot leave a
conversation with only half of a completed exchange.

## Edge Function Contract

The `ai-chat` function accepts an `action` field.

### `send_message`

Input:

- `conversation_id`, optional for a new conversation.
- `request_id`, required UUID.
- `content`, required and limited to 2,000 characters.

Processing:

1. Authenticate the JWT.
2. Verify an active `premium_subscription` whose `end_date` is in the future.
3. Enforce the configured `ai_chat` quota, defaulting to 100 user messages per
   day.
4. Resolve or create a conversation owned by the user.
5. Return the existing result when `request_id` was already processed.
6. Load at most the 12 most recent messages as DeepSeek context.
7. Ask DeepSeek for a strict JSON result containing an answer and an optional
   navigation action.
8. Validate the action against the server allowlist.
9. Store the user message, assistant message, conversation update, and usage
   entry through one transactional database RPC.
10. Return the conversation, messages, remaining quota, and optional action.

### `list_conversations`

Returns conversations owned by the current user using cursor-based or
page-based pagination. The initial page contains 20 items.

### `list_messages`

Returns messages for one owned conversation. Messages are paginated and ordered
for chat display.

### `delete_conversation`

Deletes one owned conversation after validating ownership. Deletion remains
available through the authenticated API even if the subscription has expired,
so users retain control over their data.

### `tts`

Accepts one assistant message ID. The backend loads the owned assistant message,
checks Premium, and sends its content to Vbee. The returned audio URL is cached
only in Flutter memory for the current screen session.

## DeepSeek Response Contract

DeepSeek is instructed to return:

```json
{
  "answer": "Human-readable response",
  "action": {
    "key": "trip_planner",
    "payload": {}
  }
}
```

`action` may be null.

The server accepts only these action keys:

- `trip_planner`
- `translate`
- `explore`
- `recommend`
- `forum`
- `wishlist`
- `ai_recognition`
- `loyalty`
- `popular_apps`
- `notifications`
- `profile`
- `send_report`
- `upgrade_account`

The frontend owns the mapping from action key to `AppRoutes` and derives the
localized button label from that key. DeepSeek cannot provide a raw route, URL,
or trusted display label. Unknown keys and invalid or unexpected payload fields
are removed while the text answer is preserved.

## Flutter Structure

Add a focused `features/ai_chat` module:

```text
ai_chat/
  data/
    ai_chat_repository.dart
    models/
  domain/
    ai_chat_action.dart
    ai_chat_conversation.dart
    ai_chat_message.dart
  presentation/
    ai_chat_page.dart
    ai_chat_history_page.dart
    widgets/
```

Responsibilities:

- The repository is the only boundary that invokes `ai-chat`.
- Models parse and validate the backend contract.
- A navigation-action resolver maps allowed keys to existing app routes.
- Presentation state owns pagination, optimistic user-message display, retry,
  audio playback state, and in-memory audio URL caching.
- Premium status is checked before opening the chat for a fast user experience;
  the backend remains authoritative.

## User Experience

### Home entry point

- Show a 58-pixel circular AI button above the bottom navigation.
- Constrain dragging to the safe visible area.
- Persist a normalized device-local position so it remains valid on different
  screen sizes.
- Show a lock badge to free users.
- A free user is sent to Upgrade Account after a concise Premium explanation.
- A Premium user opens the most recent chat or a new empty chat.

### Chat

- Use a full-screen chat page.
- The header contains Back, title, History, and New Chat actions.
- User messages are right-aligned; assistant messages are left-aligned.
- A valid feature suggestion appears as a clear action button under the answer.
- Navigation occurs only after the user presses the button.
- A speaker button appears on assistant messages and invokes Vbee on demand.
- The composer uses a multiline input and one Send icon button.
- Sending is disabled for empty content, content over 2,000 characters, or while
  the same request is in flight.

### History

- Show a separate history page with New Conversation at the top.
- Each row contains title, latest preview, and updated time.
- Opening a row resumes the conversation.
- A row menu allows deletion after confirmation.
- History and messages load incrementally instead of loading the entire account
  history.

## Premium And Quota Rules

- Free users can see the locked Home button but cannot enter the chat.
- `send_message` and `tts` require an active Premium subscription.
- History data remains stored after Premium expires.
- Users can delete their own conversations after Premium expires.
- The default daily chat limit is 100 sent user messages.
- The limit is configurable in the existing AI quota configuration rather than
  hard-coded in Flutter.
- Usage is logged under the `ai_chat` feature for monitoring and cost analysis.

## Error Handling

- Invalid or empty input is rejected before a network call.
- A timeout keeps the user's draft and offers Retry.
- Idempotency prevents Retry from creating duplicate messages.
- DeepSeek failure does not create an assistant message.
- Invalid DeepSeek JSON falls back to safe answer text when possible and never
  exposes an unvalidated navigation action.
- Vbee failure affects only audio and offers a speaker retry.
- A `403` Premium response opens the renewal flow.
- A quota response displays the reset time and disables sending until the next
  quota window.
- Pagination failures retain already loaded history and expose a local Retry
  control.

## Security And Privacy

- Provider keys exist only in Supabase Secrets.
- Every action authenticates the caller.
- Conversation ownership is validated in the Edge Function and protected by
  RLS.
- Only a bounded number of recent messages is sent to DeepSeek.
- Logs must not include full chat content, JWTs, API keys, or Vbee URLs.
- The system prompt treats user content as data and forbids arbitrary route,
  tool, or URL execution.
- No destructive app action is available through AI navigation.

## Performance

- Load 20 conversations per history page.
- Load messages incrementally and request older messages only when needed.
- Send only the 12 newest messages to DeepSeek.
- Generate Vbee audio only on explicit user action.
- Cache generated audio in memory for repeated playback during the current
  screen session.
- Use stable request IDs and bounded function timeouts.
- Do not block Home rendering while checking Premium; show the button
  immediately and resolve access when it is pressed.

## Testing

### Database and backend

- Conversation and message ownership policies.
- Cascade deletion.
- Pagination order and boundaries.
- Premium accepted, expired, absent, and expiring during a session.
- Default 100-message quota and configurable override.
- Duplicate `request_id` handling.
- DeepSeek normal response, no action, unknown action, malformed JSON, and
  timeout.
- Vbee success and failure.

### Flutter

- Locked and unlocked floating-button flows.
- Drag bounds on small and large screens.
- Persisted normalized floating-button position.
- New chat, resume chat, message pagination, retry, and deletion.
- Action-key mapping to every supported route.
- Unknown actions hidden safely.
- TTS invoked only when the speaker button is pressed and cached in memory.
- Premium expiration and quota presentation.
- Light and dark themes, keyboard resizing, and bottom-navigation clearance.

## Deployment Requirements

- Apply the AI chat migration.
- Deploy the `ai-chat` Edge Function.
- Keep `DEEPSEEK_API_KEY`, `VBEE_API_KEY`, and `VBEE_APP_ID` in Supabase
  Secrets.
- Configure the `ai_chat` daily quota to 100.
- No provider secret or new compile-time Flutter secret is required.
