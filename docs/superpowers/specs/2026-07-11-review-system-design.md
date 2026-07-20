# Review System Design

## Goal

Add a reusable review system that lets users submit and update one review per item across:

- `activity`
- `culture`
- `food`
- `local_product`
- `place`
- `province`
- `old_province`

Each review includes a star rating and text comment. Public item pages should show rating summaries and review lists. The system should publish clean reviews immediately, block clearly prohibited language, and support scalable review loading with infinite scroll.

## Scope

In scope:

- one-review-per-user-per-item behavior with edit support
- shared review backend for all supported content types
- rating summary aggregation with `rating_1_count` through `rating_5_count`
- keyword-based moderation using a configurable database table
- item detail review display with star breakdown, filters, and infinite scroll
- support for `activity`, `culture`, `food`, `local_product`, `place`, `province`, and `old_province`

Out of scope:

- AI moderation
- helpful votes, likes, or reactions on reviews
- media attachments in reviews
- cross-item recommendation logic based on reviews
- a dedicated `old_province` detail route if one does not already exist

## User Flow

1. The user opens an item detail page.
2. The page loads rating summary data immediately and loads the first page of reviews separately.
3. If the user has not reviewed the item, the page shows `Write a review`. If the user already reviewed it, the page shows `Edit your review`.
4. The user submits a star rating and text comment.
5. Backend validates the content type, item id, rating value, and comment text.
6. Backend runs keyword moderation.
7. If the review is clean, backend upserts the review, refreshes the rating summary, and returns the updated summary and the user's review.
8. If the review contains banned language, backend rejects the submission and asks the user to edit it.
9. The review list continues loading additional pages as the user scrolls.

## Design

### 1. Core Architecture

The review feature uses two persistent layers:

- `reviews` as the source of truth for individual user submissions
- `rating_summary` as a precomputed aggregate for fast reads on list and detail surfaces

This keeps writes slightly more involved while making reads fast and uniform across all content types.

`reviews` stores:

- reviewer identity
- target item identity
- rating
- comment
- moderation state
- timestamps

`rating_summary` stores:

- average rating
- total published review count
- per-star distribution from `rating_1_count` to `rating_5_count`
- last reviewed timestamp

The UI should always read summary data from `rating_summary`, not compute averages on the client.

### 2. Review Data Model

Recommended `reviews` columns:

- `id_review`
- `id_user`
- `content_type`
- `content_id`
- `rating`
- `comment`
- `status`
- `moderation_result`
- `created_at`
- `updated_at`

Recommended rules:

- unique constraint on `(id_user, content_type, content_id)`
- `rating` constrained to `1..5`
- `content_type` constrained to the supported values
- `comment` required for this feature

Suggested status semantics:

- `published`
- `blocked`
- `deleted`

Suggested moderation result semantics:

- `clean`
- `banned`
- `suspected`

For the first implementation, `suspected` is optional and does not need a separate runtime path if the team wants a simpler first cut. The minimum safe implementation is:

- `clean` => save and publish
- `banned` => reject submit

### 3. Rating Summary Data Model

Recommended `rating_summary` columns:

- `content_type`
- `content_id`
- `average_rating`
- `review_count`
- `rating_1_count`
- `rating_2_count`
- `rating_3_count`
- `rating_4_count`
- `rating_5_count`
- `last_reviewed_at`

Recommended rules:

- unique constraint on `(content_type, content_id)`
- counts only include reviews with `status = published`
- `average_rating` becomes `null` or `0` when there are no published reviews, depending on existing API conventions

The star-count columns exist to support a stronger review summary UI:

- progress bars for each star level
- exact breakdown of how many users selected each rating
- future admin insights into polarized or stable content quality

### 4. Content Registry And Validation

Backend should use a single content registry that maps `content_type` to its source table and id column. This avoids spreading validation logic across handlers.

Registry concept:

- `activity` -> `activity`
- `culture` -> `culture`
- `food` -> `food`
- `local_product` -> `local_products`
- `place` -> `place`
- `province` -> `province`
- `old_province` -> `old_province`

Each registry entry should define:

- source table name
- primary id column
- optional display name column if useful for logging or admin surfaces

On submit, backend must:

1. verify `content_type` is allowed
2. look up the registry entry
3. query the mapped table by `content_id`
4. reject the review if the target item does not exist

This same registry should be reused for:

- review submit validation
- review read validation
- admin review tooling
- future review analytics

### 5. Moderation Keyword Table

Keyword moderation should be stored in a dedicated table, not hardcoded in application code.

Recommended `moderation_keyword` columns:

- `id`
- `keyword`
- `normalized_keyword`
- `match_type`
- `severity`
- `language`
- `is_active`
- `note`
- `created_at`
- `updated_at`

Recommended enum meanings:

- `match_type`: `exact`, `contains`, `regex`
- `severity`: `banned`, `suspected`
- `language`: `vi`, `en`, `all`

Moderation pipeline:

1. normalize comment text
2. generate a no-accent variant for Vietnamese evasion cases
3. compare against active moderation keywords
4. decide moderation result

Recommended MVP behavior:

- any `banned` match => reject submit
- optional `suspected` match => save with internal flag as a future extension, but MVP may skip this branch entirely

To keep reads fast, backend may cache active keyword rows briefly in memory, but the source of truth remains the database table.

### 6. Submit And Update Flow

Reviews should use upsert semantics keyed by `(id_user, content_type, content_id)`.

Submit flow:

1. authenticate user
2. validate `content_type`
3. validate `content_id`
4. validate `rating`
5. validate `comment`
6. run moderation
7. insert or update the review row
8. refresh `rating_summary`
9. return updated summary and the user's review

Because each user has only one review per item:

- first submit => insert
- second submit for the same item => update existing row

This avoids duplicate user reviews while still letting the user revise their opinion later.

### 7. Summary Refresh Strategy

The first implementation should refresh `rating_summary` immediately after each successful review upsert inside the review write flow.

Recommended approach:

- handler calls a shared `refreshRatingSummary(contentType, contentId)` function after save

This is preferred over triggers for the initial version because it is:

- easier for the team to understand
- easier to test directly
- easier to debug during rollout

Summary refresh logic should recompute:

- `review_count`
- `average_rating`
- `rating_1_count`
- `rating_2_count`
- `rating_3_count`
- `rating_4_count`
- `rating_5_count`
- `last_reviewed_at`

using only published reviews for the given `(content_type, content_id)`.

### 8. Read APIs

The read model should separate fast aggregate reads from paginated review reads.

Recommended endpoints:

- `GET /review-summary?contentType=...&contentId=...`
- `GET /reviews?contentType=...&contentId=...&page=1&pageSize=10&sort=newest`
- `GET /my-review?contentType=...&contentId=...`
- `POST /reviews/upsert`

Recommended upsert response shape:

- saved review
- updated rating summary
- moderation result

This lets the detail page update immediately after submit without extra round trips.

### 9. Detail Page UX

The item detail page should render the review module in this order:

1. review summary
2. `Write a review` or `Edit your review` CTA
3. star filter chips
4. review list

Summary UI should show:

- average rating
- total review count
- five progress rows for `5` to `1` stars
- star-count labels

CTA behavior:

- no existing user review => `Write a review`
- existing user review => `Edit your review`

Review list filters:

- `All`
- `5-star`
- `4-star`
- `3-star`
- `2-star`
- `1-star`

Default sort:

- `newest`

### 10. Infinite Scroll Review Loading

Detail pages must not load all reviews at once. Review list data should use paginated infinite scroll.

Initial page load:

- request summary immediately
- request review page `1` separately

As the user scrolls near the bottom:

- request the next review page
- append results to the existing list
- stop when `hasMore = false`

Frontend responsibilities:

- maintain `isLoadingMore`
- prevent duplicate concurrent page fetches
- reset pagination when the star filter changes
- show a bottom spinner while fetching more rows

Recommended first page size:

- `10`

Recommended paginated response:

- `items`
- `page`
- `pageSize`
- `totalCount`
- `hasMore`

This keeps detail pages responsive even when an item accumulates many reviews.

### 11. Supported Frontend Surfaces

The feature should support:

- detail pages for existing explore-backed item types
- `place` review display once place detail surfaces are wired
- `province` review display
- `old_province` review display once a surface exists

For list surfaces such as explore cards, only summary data should be loaded:

- `average_rating`
- `review_count`

List surfaces should not request paginated review comments.

### 12. Scale Target: 1,000 To 10,000 Users

For the expected range of `1,000` to `10,000` users, the review system should
optimize for fast reads, bounded write cost, and low operational complexity.
This traffic level does not require queues, Redis, or distributed background
workers by default. A synchronous write path with precomputed summary reads is
the right balance.

Recommended architecture at this scale:

- `reviews` remains the source of truth for each user submission
- `rating_summary` remains the only source for rendered star counts and average rating
- review detail pages always split reads into `summary`, `list`, and optional `my review`
- list queries always stay paginated and never fetch the full review history
- star filters only reload the list, not the summary

This architecture keeps reads effectively constant-time for summary data while
keeping review-list cost proportional to the requested page size, not total
review volume.

### 13. Concrete Read And Write Strategy

#### Detail page read flow

When a user opens an item detail page, frontend should launch these requests in
parallel:

1. `getReviewSummary(contentType, contentId)`
2. `getReviews(contentType, contentId, page = 1, pageSize = 10, ratingFilter = null)`
3. `getMyReview(contentType, contentId)` if the user is authenticated

Rendering priority:

- summary should appear as soon as `getReviewSummary` returns
- list should render independently when page `1` returns
- CTA should switch from loading to `Write a review` or `Edit your review`
  when `getMyReview` resolves

Important UX rule:

- do not render placeholder rating numbers from item mock data or parent item detail fields
- if summary has not loaded yet, use a neutral loading state or skeleton

#### Review submit flow

At this scale, submit and edit should remain synchronous:

1. authenticate the user
2. validate `content_type`
3. validate `content_id`
4. confirm the target item exists in the mapped content table
5. validate `rating`
6. validate `comment`
7. run moderation
8. upsert the row into `reviews`
9. recompute exactly one summary row in `rating_summary`
10. return the saved review and updated summary to frontend

This is still appropriate for `1,000` to `10,000` users because each write
touches one review row and one summary row for one item only.

### 14. Database Index Strategy

To support fast detail-page reads at this scale, the schema should include
indexes that match the real query patterns.

Recommended `reviews` indexes:

```sql
create index if not exists reviews_content_lookup_idx
    on public.reviews (content_type, content_id, status, updated_at desc);

create index if not exists reviews_content_rating_lookup_idx
    on public.reviews (content_type, content_id, status, rating, updated_at desc);

create index if not exists reviews_user_lookup_idx
    on public.reviews (id_user, content_type, content_id);
```

Usage:

- `reviews_content_lookup_idx` supports the default `All` tab
- `reviews_content_rating_lookup_idx` supports `1-star` through `5-star` filters
- `reviews_user_lookup_idx` supports `getMyReview`

Recommended `moderation_keyword` index:

```sql
create index if not exists moderation_keyword_active_idx
    on public.moderation_keyword (is_active, severity, language);
```

The goal is to ensure that the most common detail-page queries remain index-led
even when an item accumulates a large number of reviews.

### 15. API Contract For Scalable Reads

The review API should keep summary reads separate from list reads.

#### `getReviewSummary`

Input:

- `contentType`
- `contentId`

Output:

- `average_rating`
- `review_count`
- `rating_1_count`
- `rating_2_count`
- `rating_3_count`
- `rating_4_count`
- `rating_5_count`
- `last_reviewed_at`

This payload should always come from `rating_summary`.

#### `getReviews`

Input:

- `contentType`
- `contentId`
- `page`
- `pageSize`
- optional `ratingFilter`

Output:

- `items`
- `page`
- `pageSize`
- `totalCount`
- `hasMore`

This payload should always come from paginated `reviews` rows with
`status = 'published'`.

#### `getMyReview`

Input:

- `contentType`
- `contentId`

Output:

- review object or `null`

#### `upsertReview`

Input:

- `contentType`
- `contentId`
- `rating`
- `comment`

Output:

- saved `review`
- refreshed `summary`

This contract lets frontend update the summary immediately after a successful
submit without waiting for an additional round trip.

### 16. Frontend State Model

The reusable review section should own its own state instead of relying on
parent item-detail placeholders.

Recommended state:

- `_summary`
- `_myReview`
- `_items`
- `_currentPage`
- `_hasMore`
- `_activeRatingFilter`
- `_isLoadingSummary`
- `_isLoadingFirstPage`
- `_isLoadingMore`
- `_listError`

Behavior rules:

- opening the detail page starts summary and list loading independently
- changing the star filter resets only the list state
- summary stays stable while filter changes
- submit success updates `_summary` and `_myReview`, resets the filter to `All`,
  then reloads page `1`
- infinite scroll must block duplicate page fetches while `_isLoadingMore = true`

This keeps the UI responsive and prevents large review counts from expanding
the amount of client-side work.

### 17. Cache Strategy For This User Range

For `1,000` to `10,000` users, the system should begin with light caching only.

Recommended baseline:

- in-memory frontend cache for summary per item during the current session
- optional in-memory cache for review page `1` by `(contentType, contentId, ratingFilter)`
- no Redis or dedicated cache layer required at the start

Recommended filter behavior:

- first tap on a star filter fetches from backend
- repeated taps on the same filter may reuse cached page `1`
- background refresh is optional, not required in the first release

This gives a noticeable UX improvement without introducing new infrastructure.

### 18. When To Upgrade Beyond Synchronous Summary Refresh

The current synchronous summary refresh should remain the default unless the
team observes one or more of these signs:

- review submit latency becomes noticeably slow
- a small set of items receives many review writes in a short time
- database CPU rises because many summary refreshes are happening concurrently
- write traffic starts to rival or exceed read traffic for the review feature

Only after those signals appear should the team consider:

- queued summary recomputation
- background workers
- cache invalidation layers
- more advanced aggregation pipelines

For the current target range, those additions would likely add complexity
without proportionate benefit.

## Error Handling

- unauthenticated submit => return the existing sign-in requirement behavior
- invalid `content_type` => reject
- missing target item => reject
- invalid `rating` => reject
- banned moderation match => reject with an editable user-facing error
- summary refresh failure after write should fail the operation unless the team explicitly accepts temporary summary drift
- paginated review-load failure after initial page load should keep already loaded reviews and allow retry

## Testing

### Backend tests

- submitting a first review creates a new review row
- submitting a second review for the same user and item updates the existing row
- invalid `content_type` is rejected
- missing `content_id` is rejected
- banned keyword content is rejected
- summary refresh calculates correct average, count, and `rating_1_count` through `rating_5_count`
- summary excludes blocked or deleted reviews
- paginated review query returns deterministic pages and `hasMore`

### Frontend tests

- detail page shows summary data from the API
- detail page shows `Write a review` when no user review exists
- detail page shows `Edit your review` when a user review exists
- review filter resets the paginated list and reloads page `1`
- infinite scroll appends the next page once
- detail page shows empty state when there are no reviews

### Manual verification

1. Open a supported item detail page.
2. Confirm the summary loads before the full review list finishes.
3. Submit a clean review and verify the rating summary updates.
4. Edit the same review and verify no duplicate review is created.
5. Submit a review containing a banned keyword and verify it is rejected.
6. Scroll through the review list and verify additional pages load automatically.
7. Apply a star filter and verify the list resets and loads the filtered first page.

## Risks

- the schema may need light naming alignment if current tables use slightly different id column names than the planned registry
- `old_province` may not yet have a full frontend detail surface even though the review backend supports it
- if moderation keywords are too aggressive, valid reviews may be rejected; if too weak, offensive text may slip through
- if summary refresh is not kept transactional with review writes, aggregate drift can appear

## Recommendation

Implement the smallest complete version with:

- a generic `reviews` table
- a generic `rating_summary` table with per-star counts
- a `moderation_keyword` table
- a backend content registry for item validation
- detail-page review summary plus paginated infinite-scroll review list
- synchronous per-item summary refresh
- indexes tuned for `All` and star-filtered review-list reads
- no fake summary placeholders while real review data is loading

This gives the product a scalable review foundation without requiring separate review systems for each content type.
