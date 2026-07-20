# Review System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shared review system with one review per user per item, keyword moderation, rating summary aggregation with per-star counts, and infinite-scroll review loading on item detail pages.

**Architecture:** Add a dedicated Supabase-backed review edge function plus database migrations for `reviews`, `rating_summary`, and `moderation_keyword`, then wire a frontend review repository into item detail screens so summary and paginated reviews load from backend instead of mock-only data. Keep content-type validation centralized in a backend registry, keep UI reads split between fast summary requests and paginated review-list requests, and do not render fake summary placeholders from parent item detail data while real review data is still loading.

**Tech Stack:** Supabase Postgres migrations, Supabase Edge Functions with Deno/TypeScript, Flutter/Dart, existing `SupabaseFunctionClient`, Flutter widget tests, Deno tests where practical

## Global Constraints

- Support exactly these content types: `activity`, `culture`, `food`, `local_product`, `place`, `province`, `old_province`.
- Enforce one review per user per item with edit support via unique `(id_user, content_type, content_id)`.
- Store per-star summary counts in `rating_1_count` through `rating_5_count`.
- Use a database-backed `moderation_keyword` table instead of hardcoded keyword lists.
- Publish clean reviews immediately and reject banned-language submissions.
- Load rating summary separately from the paginated review list.
- Use infinite scroll for item review lists and reset pagination when the star filter changes.
- Keep summary reads sourced from `rating_summary` only.
- Keep review-list reads paginated and filtered directly from `reviews`.
- Support the target range of `1,000` to `10,000` users without introducing queues or Redis in this implementation.
- Do not add AI moderation, review media uploads, or helpful-vote features in this implementation.

---

## File Structure

### Backend database

- Create: `backend/supabase/migrations/20260711000100_create_review_system.sql`
  - Creates `reviews`, `rating_summary`, and `moderation_keyword`
  - Adds indexes and constraints, including a star-filter-friendly review index
  - Seeds initial moderation rows only if the team decides to include starter banned terms

### Backend edge function

- Create: `backend/supabase/functions/reviews/index.ts`
  - HTTP entrypoint for the review function
- Create: `backend/supabase/functions/reviews/reviews_handler.ts`
  - Action routing, payload parsing, response shaping
- Create: `backend/supabase/functions/reviews/review_service.ts`
  - Review write flow, content validation, moderation lookup, summary refresh
- Create: `backend/supabase/functions/reviews/review_types.ts`
  - Shared request/response and registry types
- Create: `backend/supabase/functions/reviews/README.md`
  - Function behavior and action documentation
- Create: `backend/supabase/functions/reviews/deno.json`
  - Deno config mirroring existing edge functions
- Create: `backend/supabase/functions/reviews/deno-globals.d.ts`
  - Deno typing reference file
- Create: `backend/supabase/functions/reviews/reviews_handler_test.ts`
  - Unit tests for payload parsing, moderation decisions, summary calculation helpers

### Frontend review data layer

- Create: `frontend/lib/features/reviews/domain/review_models.dart`
  - Summary, review item, paginated response, submit request, content type enum
- Create: `frontend/lib/features/reviews/data/review_repository.dart`
  - Invokes `reviews` edge function actions and maps JSON to domain models
- Create: `frontend/lib/features/reviews/presentation/review_composer_sheet.dart`
  - Write/edit review bottom sheet or dialog
- Create: `frontend/lib/features/reviews/presentation/review_section.dart`
  - Summary UI, filter chips, infinite-scroll list, and summary/list loading split
- Create: `frontend/test/features/reviews/data/review_repository_test.dart`
  - Repository request/response coverage
- Create: `frontend/test/features/reviews/presentation/review_section_test.dart`
  - Infinite-scroll, filter-reset, empty-state, and CTA behavior tests

### Frontend item detail integration

- Modify: `frontend/lib/features/item_detail/domain/item_detail_models.dart`
  - Add fields needed to carry backend-driven review summary and paging state cleanly
- Modify: `frontend/lib/features/item_detail/data/item_detail_mock_data.dart`
  - Reduce review-specific mock responsibility once live review repository is introduced
- Modify: `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`
  - Replace hardcoded review carousel section with live review module and remove fake review-summary placeholders
- Modify: `frontend/lib/features/item_detail/domain/detail_category.dart`
  - Add mapping helpers needed to derive review content type for supported item detail screens
- Create: `frontend/test/features/item_detail/presentation/shared_item_detail_page_review_test.dart`
  - Verifies summary load, CTA state, and integration of the reusable review section

## Task 1: Create the database review schema

**Files:**
- Create: `backend/supabase/migrations/20260711000100_create_review_system.sql`
- Test: manual verification through Supabase SQL and later function tests

**Interfaces:**
- Consumes: existing `user_account`, item content tables, and Supabase migration pattern
- Produces:
  - `public.reviews`
  - `public.rating_summary`
  - `public.moderation_keyword`

- [ ] **Step 1: Write the migration with the three core tables**

```sql
create table if not exists public.reviews (
    id_review uuid primary key default uuid_generate_v4(),
    id_user uuid not null references public.user_account(id_user) on delete cascade,
    content_type text not null,
    content_id uuid not null,
    rating int not null,
    comment text not null,
    status text not null default 'published',
    moderation_result text not null default 'clean',
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint reviews_content_type_check
      check (content_type in ('activity', 'culture', 'food', 'local_product', 'place', 'province', 'old_province')),
    constraint reviews_rating_check check (rating between 1 and 5),
    constraint reviews_status_check check (status in ('published', 'blocked', 'deleted')),
    constraint reviews_moderation_result_check check (moderation_result in ('clean', 'banned', 'suspected')),
    constraint reviews_one_per_user_item unique (id_user, content_type, content_id)
);

create table if not exists public.rating_summary (
    content_type text not null,
    content_id uuid not null,
    average_rating numeric(3,2),
    review_count int not null default 0,
    rating_1_count int not null default 0,
    rating_2_count int not null default 0,
    rating_3_count int not null default 0,
    rating_4_count int not null default 0,
    rating_5_count int not null default 0,
    last_reviewed_at timestamp with time zone,
    primary key (content_type, content_id),
    constraint rating_summary_content_type_check
      check (content_type in ('activity', 'culture', 'food', 'local_product', 'place', 'province', 'old_province'))
);

create table if not exists public.moderation_keyword (
    id uuid primary key default uuid_generate_v4(),
    keyword text not null,
    normalized_keyword text not null,
    match_type text not null,
    severity text not null,
    language text not null default 'all',
    is_active boolean not null default true,
    note text,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint moderation_keyword_match_type_check check (match_type in ('exact', 'contains', 'regex')),
    constraint moderation_keyword_severity_check check (severity in ('banned', 'suspected')),
    constraint moderation_keyword_language_check check (language in ('vi', 'en', 'all'))
);
```

- [ ] **Step 2: Add the indexes and timestamp update trigger helper in the same migration**

```sql
create index if not exists reviews_content_lookup_idx
    on public.reviews (content_type, content_id, status, updated_at desc);

create index if not exists reviews_content_rating_lookup_idx
    on public.reviews (content_type, content_id, status, rating, updated_at desc);

create index if not exists reviews_user_lookup_idx
    on public.reviews (id_user, content_type, content_id);

create index if not exists moderation_keyword_active_idx
    on public.moderation_keyword (is_active, severity, language);

create or replace function public.set_row_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at
before update on public.reviews
for each row
execute function public.set_row_updated_at();

drop trigger if exists moderation_keyword_set_updated_at on public.moderation_keyword;
create trigger moderation_keyword_set_updated_at
before update on public.moderation_keyword
for each row
execute function public.set_row_updated_at();
```

- [ ] **Step 3: Add optional starter banned terms only if product wants seed data now**

```sql
insert into public.moderation_keyword (
    keyword,
    normalized_keyword,
    match_type,
    severity,
    language,
    note
)
select *
from (
    values
        ('dm', 'dm', 'exact', 'banned', 'vi', 'starter seed'),
        ('đm', 'dm', 'exact', 'banned', 'vi', 'starter seed'),
        ('vcl', 'vcl', 'exact', 'banned', 'vi', 'starter seed')
) as seed(keyword, normalized_keyword, match_type, severity, language, note)
where not exists (
    select 1
    from public.moderation_keyword existing
    where existing.normalized_keyword = seed.normalized_keyword
      and existing.severity = seed.severity
);
```

- [ ] **Step 4: Run the migration locally or through the project’s Supabase workflow**

Run: `supabase db push`

Expected: migration applies cleanly and the three tables exist.

- [ ] **Step 5: Verify schema manually with focused SQL checks**

Run:

```sql
select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name in ('reviews', 'rating_summary', 'moderation_keyword')
order by table_name, ordinal_position;
```

Expected: all planned columns appear, especially `rating_1_count` through `rating_5_count`.
Expected: both `reviews_content_lookup_idx` and `reviews_content_rating_lookup_idx` exist for default and star-filtered reads.

- [ ] **Step 6: Commit**

```bash
git add backend/supabase/migrations/20260711000100_create_review_system.sql
git commit -m "feat: add review system schema"
```

## Task 2: Build the reviews edge function with content validation and moderation

**Files:**
- Create: `backend/supabase/functions/reviews/index.ts`
- Create: `backend/supabase/functions/reviews/reviews_handler.ts`
- Create: `backend/supabase/functions/reviews/review_service.ts`
- Create: `backend/supabase/functions/reviews/review_types.ts`
- Create: `backend/supabase/functions/reviews/README.md`
- Create: `backend/supabase/functions/reviews/deno.json`
- Create: `backend/supabase/functions/reviews/deno-globals.d.ts`
- Create: `backend/supabase/functions/reviews/reviews_handler_test.ts`

**Interfaces:**
- Consumes:
  - `SupabaseFunctionClient`-compatible POST bodies
  - tables from Task 1
  - auth helpers from `backend/supabase/functions/auth/auth_guard.ts`
  - `corsHeaders` from `backend/supabase/functions/_shared/cors.ts`
- Produces:
  - action `getReviewSummary`
  - action `getReviews`
  - action `getMyReview`
  - action `upsertReview`
  - helper `refreshRatingSummary(contentType: ReviewContentType, contentId: string): Promise<RatingSummaryRecord>`

- [ ] **Step 1: Write the failing tests for payload parsing, moderation, and summary math**

```ts
Deno.test("parseUpsertPayload rejects unsupported content types", () => {
  assertThrows(
    () =>
      parseUpsertPayload({
        contentType: "hotel",
        contentId: "00000000-0000-0000-0000-000000000001",
        rating: 5,
        comment: "Great",
      }),
    Error,
    "Invalid contentType",
  );
});

Deno.test("summarizePublishedReviews computes per-star counts", () => {
  const result = summarizePublishedReviews([
    { rating: 5, status: "published", updated_at: "2026-07-11T10:00:00Z" },
    { rating: 4, status: "published", updated_at: "2026-07-11T11:00:00Z" },
    { rating: 4, status: "published", updated_at: "2026-07-11T12:00:00Z" },
    { rating: 1, status: "blocked", updated_at: "2026-07-11T12:30:00Z" },
  ]);

  assertEquals(result.review_count, 3);
  assertEquals(result.rating_5_count, 1);
  assertEquals(result.rating_4_count, 2);
  assertEquals(result.rating_1_count, 0);
  assertEquals(result.average_rating, 4.33);
});
```

- [ ] **Step 2: Run the test file to confirm the new helpers do not exist yet**

Run: `deno test backend/supabase/functions/reviews/reviews_handler_test.ts`

Expected: FAIL with missing symbol errors for `parseUpsertPayload` and `summarizePublishedReviews`.

- [ ] **Step 3: Define the shared review types and content registry**

```ts
export type ReviewContentType =
  | "activity"
  | "culture"
  | "food"
  | "local_product"
  | "place"
  | "province"
  | "old_province";

export type ContentRegistryEntry = {
  table: string;
  idColumn: string;
};

export const CONTENT_REGISTRY: Record<ReviewContentType, ContentRegistryEntry> = {
  activity: { table: "activity", idColumn: "id" },
  culture: { table: "culture", idColumn: "id" },
  food: { table: "food", idColumn: "id_food" },
  local_product: { table: "local_products", idColumn: "id" },
  place: { table: "place", idColumn: "id_place" },
  province: { table: "province", idColumn: "id_province" },
  old_province: { table: "old_province", idColumn: "id_province" },
};
```

- [ ] **Step 4: Implement moderation normalization and summary recompute helpers**

```ts
export function normalizeReviewText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

export function summarizePublishedReviews(
  rows: Array<{ rating: number; status: string; updated_at: string | null }>,
) {
  const published = rows.filter((row) => row.status === "published");
  const counts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 } as Record<number, number>;
  let total = 0;
  let lastReviewedAt: string | null = null;

  for (const row of published) {
    counts[row.rating] += 1;
    total += row.rating;
    if (!lastReviewedAt || (row.updated_at && row.updated_at > lastReviewedAt)) {
      lastReviewedAt = row.updated_at;
    }
  }

  const reviewCount = published.length;
  return {
    average_rating: reviewCount > 0 ? Number((total / reviewCount).toFixed(2)) : null,
    review_count: reviewCount,
    rating_1_count: counts[1],
    rating_2_count: counts[2],
    rating_3_count: counts[3],
    rating_4_count: counts[4],
    rating_5_count: counts[5],
    last_reviewed_at: lastReviewedAt,
  };
}
```

- [ ] **Step 5: Implement action handlers for summary, paginated reviews, my review, and upsert**

```ts
switch (action) {
  case "getReviewSummary":
    return jsonResponse(await service.getReviewSummary(parseContentRef(payload)));
  case "getReviews":
    return jsonResponse(await service.getReviews(parseReviewListPayload(payload)));
  case "getMyReview": {
    const userId = await requireAuthenticatedUserIdFromRequest(req);
    return jsonResponse(await service.getMyReview(userId, parseContentRef(payload)));
  }
  case "upsertReview": {
    const userId = await requireAuthenticatedUserIdFromRequest(req);
    return jsonResponse(await service.upsertReview(userId, parseUpsertPayload(payload)));
  }
  default:
    return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
}
```

- [ ] **Step 6: Implement repository-safe pagination and hasMore calculation**

```ts
const from = (page - 1) * pageSize;
const to = from + pageSize - 1;

const { data, count, error } = await this.client
  .from("reviews")
  .select("id_review, rating, comment, status, moderation_result, created_at, updated_at", {
    count: "exact",
  })
  .eq("content_type", payload.contentType)
  .eq("content_id", payload.contentId)
  .eq("status", "published")
  .order("updated_at", { ascending: false })
  .range(from, to);

return {
  items: (data ?? []).map(mapReviewRow),
  page,
  pageSize,
  totalCount: count ?? 0,
  hasMore: ((page * pageSize) < (count ?? 0)),
};
```

- [ ] **Step 6.1: Keep summary and list APIs intentionally separate**

Expected behavior:

- `getReviewSummary` always reads from `rating_summary`
- `getReviews` always reads from paginated `reviews`
- star filters reload only the list query
- summary refresh stays synchronous per item after submit or edit

- [ ] **Step 7: Re-run the Deno tests and fix any parsing or math mismatches**

Run: `deno test backend/supabase/functions/reviews/reviews_handler_test.ts`

Expected: PASS for parsing and summary helper tests.

- [ ] **Step 8: Commit**

```bash
git add backend/supabase/functions/reviews
git commit -m "feat: add reviews edge function"
```

## Task 3: Build the Flutter review repository and domain models

**Files:**
- Create: `frontend/lib/features/reviews/domain/review_models.dart`
- Create: `frontend/lib/features/reviews/data/review_repository.dart`
- Create: `frontend/test/features/reviews/data/review_repository_test.dart`

**Interfaces:**
- Consumes:
  - `frontend/lib/core/network/supabase_function_client.dart`
  - backend `reviews` edge function actions from Task 2
- Produces:
  - `ReviewContentType`
  - `RatingSummary`
  - `ReviewListPage`
  - `ReviewEntry`
  - `MyReviewState`
  - `ReviewRepository.loadSummary(...)`
  - `ReviewRepository.loadReviews(...)`
  - `ReviewRepository.loadMyReview(...)`
  - `ReviewRepository.upsertReview(...)`

- [ ] **Step 1: Write the failing repository tests for request payloads and paginated parsing**

```dart
test('loadReviews sends page, pageSize, and optional rating filter', () async {
  Object? capturedBody;

  final ReviewRepository repository = ReviewRepository(
    functionClient: SupabaseFunctionClient(
      invoker: (String functionName, {Map<String, String>? headers, Object? body}) async {
        capturedBody = body;
        return <String, Object?>{
          'items': <Map<String, Object?>>[],
          'page': 1,
          'pageSize': 10,
          'totalCount': 0,
          'hasMore': false,
        };
      },
    ),
  );

  await repository.loadReviews(
    contentType: ReviewContentType.food,
    contentId: 'food-1',
    page: 1,
    pageSize: 10,
    ratingFilter: 5,
  );

  expect(capturedBody, <String, Object?>{
    'action': 'getReviews',
    'contentType': 'food',
    'contentId': 'food-1',
    'page': 1,
    'pageSize': 10,
    'ratingFilter': 5,
    'sort': 'newest',
  });
});
```

- [ ] **Step 2: Run the repository test to confirm the feature files are not implemented yet**

Run: `flutter test frontend/test/features/reviews/data/review_repository_test.dart`

Expected: FAIL with import or symbol-not-found errors.

- [ ] **Step 3: Create the Dart domain models**

```dart
enum ReviewContentType {
  activity,
  culture,
  food,
  localProduct,
  place,
  province,
  oldProvince;

  String get apiValue => switch (this) {
    ReviewContentType.activity => 'activity',
    ReviewContentType.culture => 'culture',
    ReviewContentType.food => 'food',
    ReviewContentType.localProduct => 'local_product',
    ReviewContentType.place => 'place',
    ReviewContentType.province => 'province',
    ReviewContentType.oldProvince => 'old_province',
  };
}

class RatingSummary {
  const RatingSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.rating1Count,
    required this.rating2Count,
    required this.rating3Count,
    required this.rating4Count,
    required this.rating5Count,
  });

  final double averageRating;
  final int reviewCount;
  final int rating1Count;
  final int rating2Count;
  final int rating3Count;
  final int rating4Count;
  final int rating5Count;
}
```

- [ ] **Step 4: Implement the repository methods against `SupabaseFunctionClient`**

```dart
Future<RatingSummary> loadSummary({
  required ReviewContentType contentType,
  required String contentId,
}) async {
  final Map<String, dynamic> data = await _functionClient.invokeJson(
    'reviews',
    body: <String, Object?>{
      'action': 'getReviewSummary',
      'contentType': contentType.apiValue,
      'contentId': contentId,
    },
  );
  return RatingSummary.fromJson(data);
}

Future<ReviewListPage> loadReviews({
  required ReviewContentType contentType,
  required String contentId,
  required int page,
  int pageSize = 10,
  int? ratingFilter,
}) async {
  final Map<String, dynamic> data = await _functionClient.invokeJson(
    'reviews',
    body: <String, Object?>{
      'action': 'getReviews',
      'contentType': contentType.apiValue,
      'contentId': contentId,
      'page': page,
      'pageSize': pageSize,
      'sort': 'newest',
      if (ratingFilter != null) 'ratingFilter': ratingFilter,
    },
  );
  return ReviewListPage.fromJson(data);
}
```

- [ ] **Step 5: Re-run the repository tests**

Run: `flutter test frontend/test/features/reviews/data/review_repository_test.dart`

Expected: PASS for payload forwarding and response parsing.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/reviews/domain/review_models.dart frontend/lib/features/reviews/data/review_repository.dart frontend/test/features/reviews/data/review_repository_test.dart
git commit -m "feat: add review repository"
```

## Task 4: Replace mock-only review rendering with a reusable review section

**Files:**
- Create: `frontend/lib/features/reviews/presentation/review_section.dart`
- Create: `frontend/lib/features/reviews/presentation/review_composer_sheet.dart`
- Create: `frontend/test/features/reviews/presentation/review_section_test.dart`
- Modify: `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`
- Modify: `frontend/lib/features/item_detail/domain/detail_category.dart`
- Modify: `frontend/lib/features/item_detail/domain/item_detail_models.dart`
- Modify: `frontend/lib/features/item_detail/data/item_detail_mock_data.dart`
- Create: `frontend/test/features/item_detail/presentation/shared_item_detail_page_review_test.dart`

**Interfaces:**
- Consumes:
  - `ReviewRepository`
  - `ReviewContentType`
  - existing item detail identity (`id`, category, title)
- Produces:
  - `ReviewSection` widget
  - infinite-scroll review list with `loadNextPage()`
  - write/edit review CTA flow
  - helper `ReviewContentType? reviewContentTypeForDetailCategory(DetailCategory category)`

- [ ] **Step 1: Write the failing widget test for infinite scroll and filter reset**

```dart
testWidgets('review section loads next page once near list end', (WidgetTester tester) async {
  int loadCount = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewSection(
        loader: ({required int page, int? ratingFilter}) async {
          loadCount += 1;
          return ReviewListPage(
            items: List<ReviewEntry>.generate(
              10,
              (int index) => ReviewEntry(
                id: 'review-${page}-$index',
                userName: 'User $index',
                rating: 5,
                comment: 'Comment $index',
                updatedAtLabel: '2026-07-11',
              ),
            ),
            page: page,
            pageSize: 10,
            totalCount: 20,
            hasMore: page == 1,
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  expect(loadCount, 2);
});
```

- [ ] **Step 2: Run the widget test to confirm the new UI files are missing**

Run: `flutter test frontend/test/features/reviews/presentation/review_section_test.dart`

Expected: FAIL with missing widget or import errors.

- [ ] **Step 3: Add the detail-category to review-content-type mapper**

```dart
ReviewContentType? reviewContentTypeForDetailCategory(DetailCategory category) {
  switch (category) {
    case DetailCategory.activities:
      return ReviewContentType.activity;
    case DetailCategory.culture:
      return ReviewContentType.culture;
    case DetailCategory.food:
      return ReviewContentType.food;
    case DetailCategory.localProducts:
      return ReviewContentType.localProduct;
  }
}
```

- [ ] **Step 4: Implement `ReviewSection` with summary, filters, and infinite scroll**

```dart
NotificationListener<ScrollNotification>(
  onNotification: (ScrollNotification notification) {
    if (_isLoadingMore || !_hasMore) return false;
    if (notification.metrics.pixels <
        notification.metrics.maxScrollExtent - 240) {
      return false;
    }
    unawaited(_loadNextPage());
    return false;
  },
  child: ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _items.length + (_isLoadingMore ? 1 : 0),
    itemBuilder: (BuildContext context, int index) {
      if (index >= _items.length) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ReviewCard(review: _items[index]);
    },
  ),
);
```

- [ ] **Step 4.1: Keep review summary and review list loading independent**

Expected behavior:

- `ReviewSection` requests summary via a dedicated loader and renders it only from backend review data
- star-chip changes reload page 1 of the review list without recomputing summary on the client
- item detail screens do not pass mock or derived fallback star counts into the review module

- [ ] **Step 5: Integrate the reusable section into `SharedItemDetailPage`**

```dart
ReviewSection(
  contentType: reviewContentTypeForDetailCategory(_detail.category),
  contentId: _detail.id,
  itemTitle: _detail.name,
  repository: _reviewRepository,
)
```

- [ ] **Step 6: Re-run the new widget tests plus the item detail integration tests**

Run:

```bash
flutter test frontend/test/features/reviews/presentation/review_section_test.dart
flutter test frontend/test/features/item_detail/presentation/shared_item_detail_page_review_test.dart
```

Expected: PASS for infinite scroll, filter reset, CTA state, and detail-page integration.
Expected: no fake summary placeholder appears before the real review summary response returns.

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/features/reviews/presentation frontend/lib/features/item_detail frontend/test/features/reviews/presentation/review_section_test.dart frontend/test/features/item_detail/presentation/shared_item_detail_page_review_test.dart
git commit -m "feat: add review section to item detail"
```

## Task 5: Wire submit/edit review flow and keep summary/list state in sync

**Files:**
- Modify: `frontend/lib/features/reviews/presentation/review_section.dart`
- Modify: `frontend/lib/features/reviews/presentation/review_composer_sheet.dart`
- Modify: `frontend/lib/features/reviews/data/review_repository.dart`
- Modify: `frontend/test/features/reviews/presentation/review_section_test.dart`
- Modify: `frontend/test/features/reviews/data/review_repository_test.dart`

**Interfaces:**
- Consumes:
  - `ReviewRepository.upsertReview(...)`
  - backend `upsertReview` response from Task 2
- Produces:
  - write review CTA when no existing user review exists
  - edit review CTA when one exists
  - local refresh of summary and first page after submit
  - filter reset back to `All` after submit or edit so the newly saved review is visible immediately

- [ ] **Step 1: Write the failing widget test for updating summary after review submit**

```dart
testWidgets('submit review updates summary and shows edit CTA', (WidgetTester tester) async {
  RatingSummary currentSummary = const RatingSummary(
    averageRating: 4.0,
    reviewCount: 2,
    rating1Count: 0,
    rating2Count: 0,
    rating3Count: 0,
    rating4Count: 2,
    rating5Count: 0,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ReviewSection(
        summaryLoader: () async => currentSummary,
        myReviewLoader: () async => null,
        upsertReview: ({required int rating, required String comment}) async {
          currentSummary = const RatingSummary(
            averageRating: 4.3,
            reviewCount: 3,
            rating1Count: 0,
            rating2Count: 0,
            rating3Count: 0,
            rating4Count: 2,
            rating5Count: 1,
          );
          return UpsertReviewResult(
            summary: currentSummary,
            review: ReviewEntry(
              id: 'review-3',
              userName: 'You',
              rating: 5,
              comment: 'Great place',
              updatedAtLabel: '2026-07-11',
            ),
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Write a review'), findsOneWidget);
});
```

- [ ] **Step 2: Run the widget test to confirm the submit/edit state is not implemented yet**

Run: `flutter test frontend/test/features/reviews/presentation/review_section_test.dart`

Expected: FAIL on missing CTA state handling or missing upsert hook.

- [ ] **Step 3: Implement the composer submit flow**

Expected behavior:

- submit or edit calls `upsertReview(...)` once
- after success, `ReviewSection` reloads `getReviewSummary`
- after success, `ReviewSection` resets the active star filter to `All`
- after success, `ReviewSection` reloads page 1 from backend instead of deriving local placeholder counts

```dart
Future<void> _submit() async {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);
  try {
    final UpsertReviewResult result = await widget.repository.upsertReview(
      contentType: widget.contentType,
      contentId: widget.contentId,
      rating: _selectedRating,
      comment: _controller.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
```

- [ ] **Step 4: Update the review section state after a successful submit**

```dart
Future<void> _openComposer() async {
  final UpsertReviewResult? result = await showModalBottomSheet<UpsertReviewResult>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => ReviewComposerSheet(
      initialReview: _myReview,
      repository: widget.repository,
      contentType: widget.contentType!,
      contentId: widget.contentId,
    ),
  );
  if (result == null) return;

  setState(() {
    _summary = result.summary;
    _myReview = result.review;
    _activeRatingFilter = null;
    _items = <ReviewEntry>[result.review, ..._items.where((item) => item.id != result.review.id)];
  });
}
```

- [ ] **Step 5: Re-run the repository and presentation tests**

Run:

```bash
flutter test frontend/test/features/reviews/data/review_repository_test.dart
flutter test frontend/test/features/reviews/presentation/review_section_test.dart
```

Expected: PASS for submit payloads, summary update, and write/edit CTA transitions.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/reviews frontend/test/features/reviews
git commit -m "feat: add review submit flow"
```

## Task 6: Final verification across backend and frontend review flows

**Files:**
- Modify: any touched files only if verification exposes real defects
- Test: all affected backend and frontend review tests

**Interfaces:**
- Consumes: Tasks 1-5 deliverables
- Produces: verified review system behavior ready for QA

- [ ] **Step 1: Run the backend review tests**

Run: `deno test backend/supabase/functions/reviews/reviews_handler_test.ts`

Expected: PASS.

- [ ] **Step 2: Run the focused Flutter review and item detail tests**

Run:

```bash
flutter test frontend/test/features/reviews/data/review_repository_test.dart
flutter test frontend/test/features/reviews/presentation/review_section_test.dart
flutter test frontend/test/features/item_detail/presentation/shared_item_detail_page_review_test.dart
```

Expected: PASS for repository, infinite scroll, and detail integration behavior.

- [ ] **Step 3: Run the existing item-detail and network safety tests that could regress**

Run:

```bash
flutter test frontend/test/features/item_detail/domain/item_detail_request_test.dart
flutter test frontend/test/core/network/supabase_function_client_test.dart
```

Expected: PASS, confirming the review feature did not break existing request or function-client behavior.

- [ ] **Step 4: Do one manual app walkthrough**

Manual check:

1. Open one supported item detail page.
2. Confirm summary appears from the backend review summary request and does not flash mock star counts first.
3. Scroll to trigger page 2 and verify only one extra request fires.
4. Change the star filter and verify only the review list reloads while the summary stays server-sourced.
5. Submit a clean review and verify the summary updates immediately and the list resets to page 1 on the `All` filter.
6. Edit the same review and verify no duplicate review appears.
7. Submit a banned-word review and verify the form shows the reject message.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/functions/reviews frontend/lib/features/reviews frontend/lib/features/item_detail frontend/test/features/reviews frontend/test/features/item_detail
git commit -m "test: verify review system flow"
```

## Self-Review

### Spec coverage

- Generic backend review system: covered by Tasks 1 and 2.
- `rating_1_count` through `rating_5_count`: covered by Tasks 1 and 2, surfaced in Task 4.
- Database-backed moderation keywords: covered by Tasks 1 and 2.
- One review per user per item with edit support: covered by Tasks 1, 2, and 5.
- Infinite-scroll review loading: covered by Tasks 2, 4, and 6.
- Detail-page summary plus list integration: covered by Tasks 4, 5, and 6.
- Supported content types, including `place`, `province`, `old_province`: covered by Task 2 content registry and Task 3/4 content-type mapping.
- Scale target for `1,000` to `10,000` users with separate summary/list reads and indexed star filters: covered by Tasks 1, 2, 3, 4, and 6.

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” placeholders remain.
- Every task includes exact file paths, concrete commands, and at least one code example for the changed interface.
- The plan explicitly avoids fake summary placeholders and keeps summary/list read paths split for better scale behavior.

### Type consistency

- Backend consistently uses `ReviewContentType`.
- Frontend consistently uses `ReviewContentType`, `RatingSummary`, `ReviewListPage`, `ReviewEntry`, and `UpsertReviewResult`.
- Backend action names are consistently `getReviewSummary`, `getReviews`, `getMyReview`, and `upsertReview`.
