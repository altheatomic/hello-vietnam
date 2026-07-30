# Home Real Data and Refresh Design

**Date:** 2026-07-27

## Objective

Replace the remaining mock, synthetic, and incorrectly resolved data in the
Home experience with real Supabase data. The resulting Home page must display
valid Cloudflare R2 images, rank destinations and dishes using real ratings,
refresh without recreating the application, and personalize recommendations
from real candidates.

## Scope

This design covers four approved groups:

1. Normalize database media paths for Home, Recommend When, and Planner
   Location.
2. Replace synthetic Home ratings with `rating_summary` data.
3. Add deterministic automatic Home ranking and refresh behavior.
4. Replace the Home "Picked for you" mock candidates with real recommendation
   data.

The following are intentionally outside this change:

- Admin-selected `is_featured` and `featured_order` fields. These can be added
  later without replacing the automatic ranking path.
- A CMS-managed Home banner. The top banner and section backgrounds remain
  presentation assets.
- Voucher, loyalty tier, subscription-plan, Popular Apps, and Trip Planner
  interest-option migrations identified by the wider placeholder audit.
- Replacing legitimate loading, empty, deleted-media, and broken-image
  fallbacks.

## Current State and Confirmed Cause

The live `province` table currently has 34 rows and every row has a
`cover_image`. Those values are relative R2 keys rather than absolute URLs.
Resolving a sampled key against the configured R2 public base URL returned
HTTP 200.

`HomeRepository` passes the relative key directly to `RecommendationCard`.
That widget treats only `http://` and `https://` values as network images and
treats every other value as a Flutter asset. The database value is therefore
sent to `Image.asset` and cannot render.

Home currently also:

- starts with bundled destination and dish mock records;
- loads data only from `initState`;
- preserves the Home state inside an indexed navigation stack;
- selects four provinces without a meaningful ordering;
- selects four dishes alphabetically;
- generates ratings from an ID hash when a real rating is unavailable; and
- ranks a fixed `mockRecommendDestinations` list for "Picked for you".

## Chosen Architecture

### Server-side Home feed RPC

Add a public, read-only Supabase RPC:

```sql
public.get_home_featured_content(p_limit integer default 4) returns jsonb
```

The function is `stable`, uses `security invoker`, sets
`search_path = public`, and clamps `p_limit` to the range 1 through 12. Execute
permission is granted to `anon` and `authenticated`, matching the public Home
experience.

The returned JSON shape is:

```json
{
  "destinations": [
    {
      "id": "uuid",
      "name": "Hà Tĩnh",
      "category": "North Central Coast",
      "description": "...",
      "image_path": "provinces/.../cover/image.jpg",
      "rating": 4.7,
      "review_count": 12
    }
  ],
  "dishes": [
    {
      "id": "uuid",
      "name": "Bánh mì",
      "category": "Street food",
      "description": "...",
      "image_path": "https://...",
      "rating": null,
      "review_count": 0
    }
  ]
}
```

Destinations join `rating_summary` with `content_type = 'province'` and
`content_id = province.id_province`. Their effective rating is:

```sql
coalesce(rating_summary.average_rating, province.average_rating)
```

Dishes join `rating_summary` with `content_type = 'food'` and
`content_id = food.id_food`. No rating is invented when the join is absent.

Each content type uses this deterministic ordering:

1. rows with `review_count > 0`;
2. effective rating descending, with nulls last;
3. records with both a non-empty image and description;
4. records with a non-empty image;
5. normalized name ascending;
6. UUID ascending as a stable final tie-breaker.

This means reviewed content is preferred. Until at least four reviewed records
exist, complete real records fill the remaining slots and their rating stays
null.

### Repository boundary

`HomeRepository` calls the RPC once and maps its JSON into `Destination` and
`Dish` domain models. All non-empty `image_path` values pass through
`MediaUrlResolver.resolve` before leaving the repository.

The same boundary rule is applied to:

- `RecommendRepository`, for province cover and gallery paths;
- the Planner Location province-record mapping; and
- any Home fallback image deliberately retained as a bundled asset.

Widgets do not assemble R2 URLs. They receive only an absolute network URL, a
valid `assets/` path, or an empty value. Empty and failed images use the
existing visual fallback.

### Domain model changes

`Destination` and `Dish` gain:

```dart
final double? rating;
final int reviewCount;
```

`RecommendationCard` accepts a nullable rating and review count. It renders:

- the numeric rating when `rating != null && reviewCount > 0`;
- the localized label `No ratings yet` otherwise.

No ID-derived rating, random asset selection, or default value such as `4.5`
is used.

## Home State and Refresh Behavior

Home starts with no destination or dish records. While its first request is in
flight, the two data-backed sections show skeleton cards. The banner, feature
grid, active trip, and other independent sections remain usable.

Featured content and personalized candidates have independent states so that
failure of an authenticated recommendation call cannot hide public Home
content.

Refresh rules:

- Pull-to-refresh always requests both featured content and personalized
  candidates.
- Returning the application to the foreground refreshes data only when the
  last successful load is at least two minutes old.
- Indexed-tab navigation alone does not trigger repeated network requests.
- Concurrent refresh attempts share or await the active request.
- A successful response atomically replaces the corresponding section.

Error rules:

- On the initial featured-content failure, the two sections show a compact
  error state with a Retry action.
- On a refresh failure after successful content exists, Home retains the old
  content and shows a Snackbar.
- If personalized candidates fail, "Picked for you" shows a compact Retry
  state only when travel preferences exist. It never falls back to Picsum or
  bundled recommendation records.
- An empty successful response shows a genuine empty state, not mock content.

## Real Personalization Flow

`RecommendRepository.getPersonalizedProvinces` remains the network source for
candidate provinces. Its mapped image and gallery values are normalized using
`MediaUrlResolver`.

`TravelRecommendationService` becomes a pure ranking service:

```dart
static List<RecommendDestination> rankDestinations({
  required UserTravelPreferences preferences,
  required Iterable<RecommendDestination> candidates,
});
```

The service scores only the supplied real candidates. It retains the existing
preference-keyword scoring and uses `avgRating` only as a deterministic
tie-breaker. It no longer imports `recommend_mock_data.dart` or
`explore_mock_data.dart`.

Home loads candidates asynchronously, passes them to the pure ranker, and
shows the top four. A travel-preference change reranks the latest candidate
list locally. It does not require a new network request unless a normal
refresh is due.

The existing mock Explore lists are not replaced by this change because the
main Explore page already uses `ExploreRepository`. Removing any now-unused
mock files is allowed only when no production imports remain.

## Components and File Responsibilities

### Backend

- `backend/supabase/migrations/<timestamp>_home_featured_content_rpc.sql`
  owns the RPC, permissions, and ranking query.
- `backend/supabase/tests/home_featured_content_rpc_test.sql` verifies ranking,
  null ratings, deterministic fill behavior, and result limits.

### Flutter data and domain

- `frontend/lib/features/home/data/home_repository.dart` invokes and maps the
  RPC and resolves media URLs.
- `frontend/lib/features/home/domain/destination.dart` represents a nullable
  rating and review count.
- `frontend/lib/features/home/domain/dish.dart` represents a nullable rating
  and review count.
- `frontend/lib/features/recommend/data/recommend_repository.dart` resolves
  province cover and gallery media paths.
- `frontend/lib/features/personalization/data/travel_recommendation_service.dart`
  ranks supplied real candidates only.

### Flutter presentation

- `frontend/lib/features/home/presentation/home_page.dart` owns independent
  featured and personalized load states, pull-to-refresh, foreground refresh,
  and retry behavior.
- `frontend/lib/features/home/presentation/widgets/recommendation_card.dart`
  renders nullable ratings and already-resolved images.
- `frontend/lib/features/planner/presentation/trip_location_page.dart`
  resolves cached province media keys before building cards.
- `frontend/lib/features/recommend/presentation/when/recommend_when_results_page.dart`
  consumes the normalized recommendation URL.

No general-purpose state-management dependency is added. Existing
`StatefulWidget`, `ListenableBuilder`, repository injection, and Supabase
patterns remain in use.

## Testing Strategy

### SQL tests

The RPC test creates isolated province, food, and rating-summary fixtures and
asserts:

- a lower-rated reviewed row ranks ahead of an unreviewed row;
- higher ratings rank first among reviewed rows;
- `province.average_rating` is used only when province review-summary data is
  absent;
- an unreviewed food returns a null rating and zero reviews;
- complete unreviewed records fill a short reviewed list;
- repeated calls return the same order; and
- `p_limit` is honored and clamped.

### Dart unit tests

`home_repository_test.dart` verifies:

- one RPC payload maps to destination and dish models;
- R2 keys become absolute public URLs;
- existing absolute URLs and assets remain unchanged;
- null ratings remain null;
- review counts are preserved; and
- invalid or missing arrays produce empty real lists, not mock records.

`travel_recommendation_service_test.dart` verifies:

- only supplied candidates are returned;
- preference matches affect ordering;
- `avgRating` resolves score ties; and
- an empty candidate list remains empty.

### Widget tests

Home and card tests verify:

- skeletons appear before the first response;
- `No ratings yet` replaces fabricated scores;
- Retry is shown after an initial failure;
- old content remains after a refresh failure;
- pull-to-refresh invokes both repositories;
- personalized failure never displays mock destinations; and
- an R2 key resolved by the repository is rendered through the network-image
  path.

Planner Location and Recommend When tests verify that relative R2 keys are not
passed directly to `Image.network`.

### Project verification

Before completion:

```powershell
cd frontend
flutter analyze
flutter test
flutter build apk --debug
```

Run the Supabase SQL test suite using the repository's established database
test command. If a local Supabase stack is unavailable, run the RPC test in
the connected development project inside a transaction and roll it back.

Finally, scan production Flutter sources and require:

- no `home_mock_data.dart` import from `home_page.dart`;
- no `recommend_mock_data.dart` or `explore_mock_data.dart` import from
  `travel_recommendation_service.dart`; and
- no Picsum URL reachable from any Home section.

Other legacy mock imports found by the broader project audit are handled by
their own follow-up work and do not expand this change.

## Acceptance Criteria

- All Home destination images stored as R2 keys render from the configured
  public R2 base URL.
- Home displays exactly the ranked real records returned by the RPC.
- No visible Home rating is generated from hashes, constants, or mock data.
- Unrated content is clearly labeled rather than assigned a score.
- Pull-to-refresh updates Home without restarting the application.
- A foreground refresh occurs only after the two-minute freshness window.
- "Picked for you" contains only real candidates returned by
  `RecommendRepository`.
- A recommendation or network failure cannot cause Picsum data to appear.
- Recommend When and Planner Location correctly resolve relative R2 paths.
- Existing loading and broken-image fallbacks continue to work.
- Flutter analysis, tests, debug APK build, and the new SQL tests pass.
