# Reviews Edge Function

Invoke this function with a POST JSON body containing an `action`.

- `getReviewSummary`: `contentType`, `contentId`
- `getReviews`: `contentType`, `contentId`, optional `page`, `pageSize`, and `ratingFilter`
- `getMyReview`: authenticated; `contentType`, `contentId`
- `upsertReview`: authenticated; `contentType`, `contentId`, `rating` (1-5), and `comment`

`upsertReview` validates that the referenced content exists using the centralized
content registry. It normalizes comments before applying active
`moderation_keyword` rules. Exact and contains rules use normalized text; regex
rules use the original comment and stored regex pattern unchanged. Banned
matches are rejected before persistence; suspected matches remain published
with a `suspected` moderation result. Every accepted upsert calls the
database-side `refresh_rating_summary` RPC, which serializes recomputation for
the content key and aggregates published reviews only.

Run focused tests with:

```powershell
deno test --config backend/supabase/functions/reviews/deno.json backend/supabase/functions/reviews
```
