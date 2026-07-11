# Reviews Edge Function

Invoke this function with a POST JSON body containing an `action`.

- `getReviewSummary`: `contentType`, `contentId`
- `getReviews`: `contentType`, `contentId`, optional `page` and `pageSize`
- `getMyReview`: authenticated; `contentType`, `contentId`
- `upsertReview`: authenticated; `contentType`, `contentId`, `rating` (1-5), and `comment`

`upsertReview` validates that the referenced content exists using the centralized
content registry. It normalizes comments before applying active
`moderation_keyword` rules. Banned matches are saved as blocked and excluded
from rating summaries; suspected matches remain published with a `suspected`
moderation result. Every upsert recomputes `rating_summary` from published
reviews.

Run focused tests with:

```powershell
& 'C:\Users\ASUS\AppData\Local\Microsoft\WinGet\Links\deno.exe' test --config backend/supabase/functions/reviews/deno.json backend/supabase/functions/reviews/reviews_handler_test.ts
```
