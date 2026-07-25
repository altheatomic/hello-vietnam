# AI Chat Performance Implementation Plan

1. Add tests for a consolidated send preparation result and structured timing.
2. Add `prepare_ai_chat_request` and `list_ai_chat_messages` SQL functions.
3. Make `commit_ai_chat_exchange` enforce quota under a transaction lock.
4. Replace the Edge Function's separate Premium, ownership, quota, and history
   queries with the new RPCs.
5. Add Flutter tests for failed-draft retention, Premium caching, and stable
   scroll behavior.
6. Implement the shared Premium cache and make `send` return a result.
7. Refactor the chat page so only dynamic content listens to the controller.
8. Run focused Deno/Flutter tests, formatter, analyzer, and inspect the final
   diff without touching unrelated worktree changes.
