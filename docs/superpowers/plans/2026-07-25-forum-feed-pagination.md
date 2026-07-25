# Forum Feed Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Forum feed's client-side overfetch with stable backend cursor pagination and load post comments independently as the user opens and scrolls a thread.

**Architecture:** PostgreSQL RPC functions return fully aggregated feed rows and comment rows, ordered by `(created_at, id)` descending with a two-part cursor. Flutter maps those rows into existing domain models; `ForumStore` owns separate pagination state for each feed and each post's comments, while `ThreadPage` requests comments only when needed.

**Tech Stack:** PostgreSQL/Supabase RPC, Dart/Flutter, `supabase_flutter`, `flutter_test`

## Global Constraints

- Preserve existing Forum UI, create/edit/delete, likes, bookmarks, follow, block, report, and notification behavior.
- Load at most 20 feed posts or comments per request by default; RPC functions clamp requests to 50.
- Never fall back to loading all likes, comments, profiles, or follows for a feed page.
- Use `(created_at, UUID)` cursor ordering so equal timestamps cannot skip or duplicate rows.
- Keep unrelated dirty workspace files untouched.

---

### Task 1: Stable Cursor Model

**Files:**
- Create: `frontend/lib/features/forum/data/forum_page_cursor.dart`
- Create: `frontend/test/features/forum/data/forum_page_cursor_test.dart`

**Interfaces:**
- Produces: `ForumPageCursor({required DateTime createdAt, required String id})`
- Produces: `ForumPageCursor.fromRow(Map<String, dynamic> row, {required String idKey})`
- Produces: `Map<String, dynamic> toRpcArguments({required String createdAtKey, required String idKey})`

- [ ] **Step 1: Write failing cursor tests**

Test that `fromRow` parses UTC timestamps and IDs, rejects missing values, and that `toRpcArguments` emits the exact ISO timestamp and UUID expected by Supabase RPC.

- [ ] **Step 2: Run the cursor test and verify RED**

Run:

```powershell
flutter test test/features/forum/data/forum_page_cursor_test.dart
```

Expected: compilation failure because `ForumPageCursor` does not exist.

- [ ] **Step 3: Implement the immutable cursor**

Create a small value object with equality/hashCode, strict row validation, UTC normalization, and RPC argument conversion.

- [ ] **Step 4: Run the cursor test and verify GREEN**

Run:

```powershell
flutter test test/features/forum/data/forum_page_cursor_test.dart
```

Expected: all tests pass.

---

### Task 2: Backend Feed and Comment RPCs

**Files:**
- Create: `backend/supabase/migrations/20260725000100_forum_feed_page_rpc.sql`
- Create: `backend/supabase/tests/forum_feed_page_rpc_test.sql`

**Interfaces:**
- Produces: `public.forum_feed_page(p_feed text, p_limit integer, p_before_created_at timestamptz, p_before_post_id uuid)`
- Produces: `public.forum_comments_page(p_post_id uuid, p_limit integer, p_before_created_at timestamptz, p_before_comment_id uuid)`

- [ ] **Step 1: Write SQL contract tests**

Add transactional SQL assertions for:

- only active posts/comments;
- blocked authors excluded;
- `following` contains only followed authors;
- stable cursor behavior when two rows share a timestamp;
- per-user liked, bookmarked, followed, and reported flags;
- comment counts are returned without returning comment bodies in the feed.

- [ ] **Step 2: Run the SQL test and verify RED when a local Supabase database is available**

Run:

```powershell
npx supabase test db backend/supabase/tests/forum_feed_page_rpc_test.sql
```

Expected before migration: missing function error. If Docker/local Supabase is unavailable, record that limitation and validate the migration using remote `db push --dry-run` later.

- [ ] **Step 3: Implement both security-invoker RPC functions and indexes**

The feed RPC must:

- require `auth.uid()`;
- validate feed/cursor arguments;
- clamp page size from 1 to 50;
- filter with row-value comparison `(created_at, id_post) < (...)`;
- aggregate media, counts, and current-user flags server-side;
- return author metadata and follower/following counts.

The comments RPC must return author metadata, like count, and current-user like state using the same cursor pattern.

Add composite partial indexes for feed posts and post comments, plus current-user report lookup.

- [ ] **Step 4: Re-run SQL verification**

Run the local SQL test if available and:

```powershell
npx supabase db push --dry-run
```

Expected: migration parses and is selected for deployment.

---

### Task 3: Repository Uses Aggregated RPC Rows

**Files:**
- Modify: `frontend/lib/features/forum/data/forum_repository.dart`
- Create: `frontend/test/features/forum/data/forum_repository_row_mapper_test.dart`

**Interfaces:**
- Changes: `ForumRepositorySnapshot.nextForYouCursor` and `nextFollowingCursor` to `ForumPageCursor?`
- Adds: `Future<ForumCommentsPage> loadCommentsPage({required String postId, ForumPageCursor? beforeCursor, int limit = 20})`
- Produces: `ForumCommentsPage(comments, nextCursor, hasMore)`

- [ ] **Step 1: Write failing row-mapper tests**

Cover feed row conversion into `ForumPost`/`ForumUserProfile`, empty media arrays, numeric counts, shared item payloads, and comment row conversion.

- [ ] **Step 2: Run repository tests and verify RED**

Run:

```powershell
flutter test test/features/forum/data/forum_repository_row_mapper_test.dart
```

Expected: compilation failure because RPC row mapping and comment page APIs do not exist.

- [ ] **Step 3: Replace feed overfetch with RPC calls**

Call `forum_feed_page` once per requested feed page, in parallel when both feeds are requested. Derive the next cursor from the final row, set `commentsByPostId` to an empty map, and keep notification/current-profile loading independent.

- [ ] **Step 4: Add independent comment page loading**

Call `forum_comments_page`, map rows, and return `ForumCommentsPage`. Do not query all comments or comment likes from `loadSnapshot`.

- [ ] **Step 5: Run repository tests and verify GREEN**

Run:

```powershell
flutter test test/features/forum/data/forum_repository_row_mapper_test.dart
```

Expected: all tests pass.

---

### Task 4: Store Owns Per-Post Comment Pagination

**Files:**
- Modify: `frontend/lib/features/forum/data/forum_store.dart`
- Modify: `frontend/test/features/forum/data/forum_store_test.dart`

**Interfaces:**
- Adds: `Future<void> ensureCommentsLoaded(String postId, {bool forceRefresh = false})`
- Adds: `Future<void> loadMoreComments(String postId)`
- Adds getters: `isLoadingComments`, `isLoadingMoreComments`, `hasMoreComments`, `commentError`

- [ ] **Step 1: Update the fake repository and write failing store tests**

Test initial comment load, request coalescing, append-with-deduplication, cursor forwarding, load-more exhaustion, and failed-request retry.

- [ ] **Step 2: Run focused store tests and verify RED**

Run:

```powershell
flutter test test/features/forum/data/forum_store_test.dart
```

Expected: compilation failures for the new comment pagination APIs.

- [ ] **Step 3: Implement per-post state and request coalescing**

Store cursor, `hasMore`, initial-loading, load-more, and error state by post ID. Merge comments by ID while preserving newest-first order and keep optimistic `addReply` behavior.

- [ ] **Step 4: Run focused store tests and verify GREEN**

Run:

```powershell
flutter test test/features/forum/data/forum_store_test.dart
```

Expected: all tests pass.

---

### Task 5: Thread UI Loads Comments on Demand

**Files:**
- Modify: `frontend/lib/features/forum/presentation/thread_page.dart`
- Create: `frontend/test/features/forum/presentation/thread_page_test.dart`

**Interfaces:**
- Consumes: `ForumStore.ensureCommentsLoaded`, `loadMoreComments`, and comment state getters.

- [ ] **Step 1: Write failing widget tests**

Verify that opening a thread triggers one initial comment request, shows initial loading/error/retry/empty states, and requests another page only when scrolling near the bottom.

- [ ] **Step 2: Run widget tests and verify RED**

Run:

```powershell
flutter test test/features/forum/presentation/thread_page_test.dart
```

Expected: existing thread does not request independent comments.

- [ ] **Step 3: Implement lifecycle and scroll pagination**

Convert the page to a stateful widget, request comments after the first frame, listen for near-bottom scrolling, and render compact initial/loading-more/error states without changing the post card or reply composer behavior.

- [ ] **Step 4: Run widget tests and verify GREEN**

Run:

```powershell
flutter test test/features/forum/presentation/thread_page_test.dart
```

Expected: all tests pass.

---

### Task 6: Regression Verification

**Files:**
- Modify only files required by failures caused by Tasks 1–5.

- [ ] **Step 1: Format changed Dart files**

```powershell
dart format lib/features/forum test/features/forum
```

- [ ] **Step 2: Run Forum tests**

```powershell
flutter test test/features/forum
```

- [ ] **Step 3: Run static analysis**

```powershell
flutter analyze
```

- [ ] **Step 4: Review the scoped diff**

```powershell
git diff --check
git diff -- backend/supabase/migrations/20260725000100_forum_feed_page_rpc.sql frontend/lib/features/forum frontend/test/features/forum
```

- [ ] **Step 5: Document deployment command**

After review, the user deploys the RPC migration with:

```powershell
cd backend
npx supabase db push
```

No Edge Function deployment is required for these RPC-only changes.
