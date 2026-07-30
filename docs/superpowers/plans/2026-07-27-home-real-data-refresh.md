# Home Real Data and Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Home, Recommend When, and Planner Location render real Supabase data and R2 images, rank Home content using real ratings, refresh safely, and build "Picked for you" from real candidates.

**Architecture:** A read-only Supabase RPC performs deterministic server-side ranking and returns one Home payload. Flutter repositories normalize every media key at their boundary, a focused `HomeContentController` owns refresh state, and a pure personalization service ranks only candidates supplied by `RecommendRepository`.

**Tech Stack:** PostgreSQL/Supabase RPC and SQL transaction tests; Flutter 3.38.9+; Dart 3.10.8+; `supabase_flutter`; existing `ChangeNotifier`, `MediaUrlResolver`, repository injection, and Flutter test tooling.

**Approved design:** `docs/superpowers/specs/2026-07-27-home-real-data-refresh-design.md`

## Global Constraints

- Do not add a new Flutter package or state-management dependency.
- Keep the top Home banner and section backgrounds as bundled design assets.
- Do not add `is_featured` or `featured_order` in this change.
- Do not generate ratings from hashes, constants, random values, or mock data.
- Unreviewed content must expose `rating == null`, `reviewCount == 0`, and render `No ratings yet`.
- Prefer reviewed content; fill missing slots with complete real records.
- Normalize database media paths before they reach presentation widgets.
- Pull-to-refresh is unconditional; foreground refresh uses a two-minute freshness window.
- Never fall back to Picsum or bundled recommendation records in a Home data path.
- Preserve all unrelated dirty files already present in the working tree.

---

### Task 1: Add the ranked Home feed RPC

**Files:**
- Create: `backend/supabase/tests/home_featured_content_rpc_test.sql`
- Create: `backend/supabase/migrations/20260727000200_home_featured_content_rpc.sql`

**Interfaces:**
- Produces: `public.get_home_featured_content(p_limit integer default 4) returns jsonb`
- JSON keys: `destinations`, `dishes`
- Item keys: `id`, `name`, `category`, `description`, `image_path`, `rating`, `review_count`

- [ ] **Step 1: Write the failing SQL transaction test**

Create `backend/supabase/tests/home_featured_content_rpc_test.sql` with fixed UUID
fixtures and assertions against the missing function:

```sql
begin;

insert into public.province (
  id_province, name, region_code, detailed_description,
  cover_image, average_rating
) values
  ('00000000-0000-0000-0000-00000000a001', '__home_rpc_reviewed_high',
   'Test', 'complete', 'province/high.jpg', 4.10),
  ('00000000-0000-0000-0000-00000000a002', '__home_rpc_reviewed_low',
   'Test', 'complete', 'province/low.jpg', 4.90),
  ('00000000-0000-0000-0000-00000000a003', '__home_rpc_unreviewed',
   'Test', 'complete', 'province/unreviewed.jpg', 9.50);

insert into public.food (
  id_food, name, type, image_path, description
) values
  ('00000000-0000-0000-0000-00000000b001', '__home_rpc_food_reviewed',
   'Test', 'food/reviewed.jpg', 'complete'),
  ('00000000-0000-0000-0000-00000000b002', '__home_rpc_food_unreviewed',
   'Test', 'food/unreviewed.jpg', 'complete');

insert into public.rating_summary (
  content_type, content_id, average_rating, review_count,
  rating_1_count, rating_2_count, rating_3_count,
  rating_4_count, rating_5_count
) values
  ('province', '00000000-0000-0000-0000-00000000a001', 9.90, 3, 0, 0, 0, 0, 3),
  ('province', '00000000-0000-0000-0000-00000000a002', 9.80, 2, 0, 0, 0, 1, 1),
  ('food', '00000000-0000-0000-0000-00000000b001', 9.70, 1, 0, 0, 0, 0, 1);

do $$
declare
  v_first jsonb := public.get_home_featured_content(12);
  v_second jsonb := public.get_home_featured_content(12);
  v_destinations jsonb;
  v_dishes jsonb;
  v_high_index integer;
  v_low_index integer;
  v_unreviewed jsonb;
begin
  v_destinations := v_first -> 'destinations';
  v_dishes := v_first -> 'dishes';

  if v_first is distinct from v_second then
    raise exception 'Home RPC order is not deterministic';
  end if;

  select ordinal - 1 into v_high_index
  from jsonb_array_elements(v_destinations) with ordinality item(value, ordinal)
  where value ->> 'id' = '00000000-0000-0000-0000-00000000a001';

  select ordinal - 1 into v_low_index
  from jsonb_array_elements(v_destinations) with ordinality item(value, ordinal)
  where value ->> 'id' = '00000000-0000-0000-0000-00000000a002';

  if v_high_index is null or v_low_index is null or v_high_index >= v_low_index then
    raise exception 'Reviewed destination rating order is incorrect';
  end if;

  select value into v_unreviewed
  from jsonb_array_elements(v_destinations) item(value)
  where value ->> 'id' = '00000000-0000-0000-0000-00000000a003';

  if v_unreviewed is null
     or v_unreviewed -> 'rating' <> 'null'::jsonb
     or (v_unreviewed ->> 'review_count')::integer <> 0 then
    raise exception 'Unreviewed destination exposed a fabricated rating';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_dishes) item(value)
    where value ->> 'id' = '00000000-0000-0000-0000-00000000b002'
      and value -> 'rating' = 'null'::jsonb
      and (value ->> 'review_count')::integer = 0
  ) then
    raise exception 'Unreviewed food was not returned as unrated';
  end if;

  if jsonb_array_length(public.get_home_featured_content(100) -> 'destinations') > 12
     or jsonb_array_length(public.get_home_featured_content(0) -> 'destinations') > 1 then
    raise exception 'p_limit clamp is incorrect';
  end if;
end
$$;

rollback;
```

- [ ] **Step 2: Run the test and confirm the missing RPC failure**

Run against a migrated development database:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
  -f backend/supabase/tests/home_featured_content_rpc_test.sql
```

Expected: failure containing `function public.get_home_featured_content(integer) does not exist`.

- [ ] **Step 3: Implement the RPC migration**

Create `backend/supabase/migrations/20260727000200_home_featured_content_rpc.sql`:

```sql
create or replace function public.get_home_featured_content(
  p_limit integer default 4
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 4), 12));
begin
  return (
    with destination_candidates as (
      select
        p.id_province as id,
        trim(coalesce(p.name, '')) as name,
        coalesce(nullif(trim(p.region_code), ''), 'Vietnam destination') as category,
        coalesce(
          nullif(trim(p.detailed_description), ''),
          nullif(trim(p.short_description), '')
        ) as description,
        trim(coalesce(p.cover_image, '')) as image_path,
        case
          when coalesce(rs.review_count, 0) > 0 then rs.average_rating
          else null
        end as display_rating,
        coalesce(rs.review_count, 0)::integer as review_count,
        coalesce(rs.average_rating, p.average_rating) as rank_rating,
        (
          case when nullif(trim(p.cover_image), '') is not null then 1 else 0 end
          + case when coalesce(
              nullif(trim(p.detailed_description), ''),
              nullif(trim(p.short_description), '')
            ) is not null then 1 else 0 end
        ) as completeness
      from public.province p
      left join public.rating_summary rs
        on rs.content_type = 'province'
       and rs.content_id = p.id_province
      where p.id_province is not null
        and nullif(trim(p.name), '') is not null
    ),
    destinations as (
      select *
      from destination_candidates
      order by
        (review_count > 0) desc,
        rank_rating desc nulls last,
        completeness desc,
        lower(name),
        id
      limit v_limit
    ),
    dish_candidates as (
      select
        f.id_food as id,
        trim(coalesce(f.name, '')) as name,
        coalesce(nullif(trim(f.type), ''), 'Vietnamese dish') as category,
        nullif(trim(f.description), '') as description,
        trim(coalesce(f.image_path, '')) as image_path,
        case
          when coalesce(rs.review_count, 0) > 0 then rs.average_rating
          else null
        end as display_rating,
        coalesce(rs.review_count, 0)::integer as review_count,
        rs.average_rating as rank_rating,
        (
          case when nullif(trim(f.image_path), '') is not null then 1 else 0 end
          + case when nullif(trim(f.description), '') is not null then 1 else 0 end
        ) as completeness
      from public.food f
      left join public.rating_summary rs
        on rs.content_type = 'food'
       and rs.content_id = f.id_food
      where nullif(trim(f.name), '') is not null
    ),
    dishes as (
      select *
      from dish_candidates
      order by
        (review_count > 0) desc,
        rank_rating desc nulls last,
        completeness desc,
        lower(name),
        id
      limit v_limit
    )
    select jsonb_build_object(
      'destinations',
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', id,
            'name', name,
            'category', category,
            'description', description,
            'image_path', image_path,
            'rating', display_rating,
            'review_count', review_count
          )
          order by
            (review_count > 0) desc,
            rank_rating desc nulls last,
            completeness desc,
            lower(name),
            id
        )
        from destinations
      ), '[]'::jsonb),
      'dishes',
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', id,
            'name', name,
            'category', category,
            'description', description,
            'image_path', image_path,
            'rating', display_rating,
            'review_count', review_count
          )
          order by
            (review_count > 0) desc,
            rank_rating desc nulls last,
            completeness desc,
            lower(name),
            id
        )
        from dishes
      ), '[]'::jsonb)
    )
  );
end;
$$;

revoke all on function public.get_home_featured_content(integer) from public;
grant execute on function public.get_home_featured_content(integer)
  to anon, authenticated;
```

- [ ] **Step 4: Apply the migration and rerun the SQL test**

Apply the migration using the repository's normal Supabase deployment flow,
then rerun:

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
  -f backend/supabase/tests/home_featured_content_rpc_test.sql
```

Expected: exit code 0 with no raised exception.

- [ ] **Step 5: Commit the database deliverable**

```powershell
git add backend/supabase/migrations/20260727000200_home_featured_content_rpc.sql `
  backend/supabase/tests/home_featured_content_rpc_test.sql
git commit -m "feat: add ranked Home content RPC"
```

---

### Task 2: Map RPC data into real Home domain models

**Files:**
- Modify: `frontend/test/features/home/data/home_repository_test.dart`
- Modify: `frontend/lib/features/home/domain/destination.dart`
- Modify: `frontend/lib/features/home/domain/dish.dart`
- Modify: `frontend/lib/features/home/data/home_repository.dart`

**Interfaces:**
- Produces: `typedef HomeRpcInvoker = Future<Object?> Function(int limit)`
- Produces: `Destination.rating` and `Dish.rating` as `double?`
- Produces: `Destination.reviewCount` and `Dish.reviewCount` as `int`
- `HomeRepository.fetchFeaturedContent({int limit = 4})` remains the public entrypoint

- [ ] **Step 1: Replace the table-client test with failing RPC mapping tests**

Use an injected `HomeRpcInvoker` and a test media base:

```dart
test('maps one RPC payload and resolves R2 media keys', () async {
  int? requestedLimit;
  final HomeRepository repository = HomeRepository(
    rpcInvoker: (int limit) async {
      requestedLimit = limit;
      return <String, dynamic>{
        'destinations': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'province-1',
            'name': 'Ha Tinh',
            'category': 'North Central',
            'description': 'Coastal province',
            'image_path': 'provinces/ha-tinh/cover.jpg',
            'rating': 4.75,
            'review_count': 8,
          },
        ],
        'dishes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'food-1',
            'name': 'Bun bo Hue',
            'category': 'Noodle',
            'image_path': 'https://cdn.example.test/bun-bo.jpg',
            'rating': null,
            'review_count': 0,
          },
        ],
      };
    },
    mediaPublicBaseUrl: 'https://media.example.test',
  );

  final HomeFeaturedContent content =
      await repository.fetchFeaturedContent(limit: 4);

  expect(requestedLimit, 4);
  expect(
    content.destinations.single.imagePath,
    'https://media.example.test/provinces/ha-tinh/cover.jpg',
  );
  expect(content.destinations.single.rating, 4.75);
  expect(content.destinations.single.reviewCount, 8);
  expect(content.dishes.single.rating, isNull);
  expect(content.dishes.single.reviewCount, 0);
});

test('invalid or missing arrays map to empty real lists', () async {
  final HomeRepository repository = HomeRepository(
    rpcInvoker: (_) async => <String, dynamic>{'destinations': null},
  );

  final HomeFeaturedContent content =
      await repository.fetchFeaturedContent();

  expect(content.destinations, isEmpty);
  expect(content.dishes, isEmpty);
});
```

- [ ] **Step 2: Run the focused test and verify type/mapping failures**

```powershell
Push-Location frontend
flutter test test/features/home/data/home_repository_test.dart
Pop-Location
```

Expected: failure because `rpcInvoker`, nullable ratings, and `reviewCount` do not exist.

- [ ] **Step 3: Update the two domain models**

Use these fields and tolerant factories in both models:

```dart
final double? rating;
final int reviewCount;

const Destination({
  required this.id,
  required this.name,
  required this.category,
  required this.rating,
  this.reviewCount = 0,
  required this.imagePath,
  this.isFavorite = false,
  this.description,
});
```

For JSON mapping:

```dart
rating: (json['rating'] as num?)?.toDouble(),
reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
```

Apply the same change to `Dish`. Keep `reviewCount = 0` as a constructor default
so the existing static feature data continues to compile until it is removed in
Task 8; every repository mapper in this plan still passes the real count
explicitly.

- [ ] **Step 4: Replace direct table queries with the RPC mapper**

Implement these repository boundaries:

```dart
typedef HomeRpcInvoker = Future<Object?> Function(int limit);

class HomeRepository {
  HomeRepository({
    SupabaseClient? client,
    HomeRpcInvoker? rpcInvoker,
    String mediaPublicBaseUrl = Env.cloudflareMediaPublicBaseUrl,
  }) : _clientOverride = client,
       _rpcInvoker = rpcInvoker,
       _mediaPublicBaseUrl = mediaPublicBaseUrl;

  final SupabaseClient? _clientOverride;
  final HomeRpcInvoker? _rpcInvoker;
  final String _mediaPublicBaseUrl;

  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  Future<HomeFeaturedContent> fetchFeaturedContent({int limit = 4}) async {
    final Object? raw = await (_rpcInvoker?.call(limit) ??
        _client.rpc(
          'get_home_featured_content',
          params: <String, Object?>{'p_limit': limit},
        ));
    final Map<String, dynamic> payload = _asMap(raw);
    return HomeFeaturedContent(
      destinations: _asRows(payload['destinations'])
          .map(_destinationFromRow)
          .toList(growable: false),
      dishes: _asRows(payload['dishes'])
          .map(_dishFromRow)
          .toList(growable: false),
    );
  }

  Destination _destinationFromRow(Map<String, dynamic> row) {
    return Destination(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      description: row['description']?.toString(),
      imagePath: _resolveMedia(row['image_path']),
      rating: (row['rating'] as num?)?.toDouble(),
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  Dish _dishFromRow(Map<String, dynamic> row) {
    return Dish(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      imagePath: _resolveMedia(row['image_path']),
      rating: (row['rating'] as num?)?.toDouble(),
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  String _resolveMedia(Object? raw) => MediaUrlResolver.resolve(
    raw?.toString() ?? '',
    publicBaseUrl: _mediaPublicBaseUrl,
  );

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) return <String, dynamic>{};
    return raw.map<String, dynamic>(
      (Object? key, Object? value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }

  static List<Map<String, dynamic>> _asRows(Object? raw) {
    if (raw is! List<Object?>) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map<Map<String, dynamic>>(
          (Map<Object?, Object?> row) => row.map<String, dynamic>(
            (Object? key, Object? value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }
}
```

Delete `_ratingFromSeed`, `_rowRating`, `_destinationFallbackImage`,
`_dishFallbackImage`, and the old `SupabaseTableClient` dependency.

- [ ] **Step 5: Run repository and resolver tests**

```powershell
Push-Location frontend
flutter test test/features/home/data/home_repository_test.dart `
  test/core/media/media_url_resolver_test.dart
Pop-Location
```

Expected: all tests pass.

- [ ] **Step 6: Commit the repository boundary**

```powershell
git add frontend/lib/features/home/data/home_repository.dart `
  frontend/lib/features/home/domain/destination.dart `
  frontend/lib/features/home/domain/dish.dart `
  frontend/test/features/home/data/home_repository_test.dart
git commit -m "feat: load real ranked content on Home"
```

---

### Task 3: Render nullable ratings without fabricated stars

**Files:**
- Create: `frontend/test/features/home/presentation/widgets/recommendation_card_test.dart`
- Modify: `frontend/lib/features/home/presentation/widgets/recommendation_card.dart`
- Modify: `frontend/lib/features/home/presentation/home_page.dart`

**Interfaces:**
- `RecommendationCard.rating` becomes `double?`
- `RecommendationCard.reviewCount` is required
- `_FavoriteRecommendationCard` forwards the same pair

- [ ] **Step 1: Write failing rating widget tests**

```dart
testWidgets('shows localized no-rating copy for an unreviewed item', (
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 240,
          child: RecommendationCard(
            name: 'Bun bo Hue',
            category: 'Food',
            rating: null,
            reviewCount: 0,
            imagePath: '',
          ),
        ),
      ),
    ),
  );

  expect(find.text('No ratings yet'), findsOneWidget);
  expect(find.byIcon(Icons.star_rounded), findsNothing);
});

testWidgets('shows a numeric rating only when reviews exist', (
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 240,
          child: RecommendationCard(
            name: 'Ha Tinh',
            category: 'Destination',
            rating: 4.75,
            reviewCount: 8,
            imagePath: '',
          ),
        ),
      ),
    ),
  );

  expect(find.text('4.75'), findsOneWidget);
  expect(find.byIcon(Icons.star_rounded), findsOneWidget);
});
```

- [ ] **Step 2: Run the test and verify constructor failures**

```powershell
Push-Location frontend
flutter test test/features/home/presentation/widgets/recommendation_card_test.dart
Pop-Location
```

Expected: failure because `rating` is non-nullable and `reviewCount` is absent.

- [ ] **Step 3: Implement the conditional rating row**

Import `package:hellovietnam/core/language/app_language.dart`, then add:

```dart
final double? rating;
final int reviewCount;

bool get _hasRating => rating != null && reviewCount > 0;
```

Replace the unconditional star and number with:

```dart
if (_hasRating) ...<Widget>[
  const Icon(Icons.star_rounded, size: 16, color: AppColors.starColor),
  const SizedBox(width: 2),
  Text(
    rating!.toStringAsFixed(2),
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: primaryText,
    ),
  ),
] else
  Flexible(
    child: Text(
      context.l10n.reviewSummaryLabel(0),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: secondaryText),
    ),
  ),
```

Update `_FavoriteRecommendationCard`, destination cards, and dish cards in
`home_page.dart` to pass both values. The existing personalized call site
temporarily passes `reviewCount: 0`; Task 4 adds the real review count to
`RecommendDestination`, and Task 7 switches that call site to
`d.reviewCount`.

- [ ] **Step 4: Run the focused widget test**

```powershell
Push-Location frontend
flutter test test/features/home/presentation/widgets/recommendation_card_test.dart
Pop-Location
```

Expected: all tests pass.

- [ ] **Step 5: Commit nullable-rating presentation**

```powershell
git add frontend/lib/features/home/presentation/widgets/recommendation_card.dart `
  frontend/lib/features/home/presentation/home_page.dart `
  frontend/test/features/home/presentation/widgets/recommendation_card_test.dart
git commit -m "fix: show unrated Home content honestly"
```

---

### Task 4: Normalize Recommend and Planner province media

**Files:**
- Create: `frontend/test/features/recommend/data/recommend_repository_test.dart`
- Create: `frontend/lib/features/planner/data/planner_province.dart`
- Create: `frontend/test/features/planner/data/planner_province_test.dart`
- Modify: `frontend/lib/features/recommend/domain/recommend_destination.dart`
- Modify: `frontend/lib/features/recommend/data/recommend_repository.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_location_page.dart`
- Verify: `frontend/lib/features/recommend/presentation/when/recommend_when_results_page.dart`

**Interfaces:**
- Produces: `typedef RecommendMediaResolver = String Function(String rawValue)`
- Produces: `RecommendDestination.reviewCount`
- Produces: `PlannerProvince.fromReferenceRecord(...)`

- [ ] **Step 1: Write the failing Recommend repository test**

Construct `SupabaseFunctionClient` with an injected invoker:

```dart
test('resolves province cover and gallery keys from the function response', () async {
  final RecommendRepository repository = RecommendRepository(
    functionClient: SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (
        String functionName, {
        Map<String, String>? headers,
        Object? body,
      }) async {
        return <String, dynamic>{
          'provinces': <Map<String, dynamic>>[
            <String, dynamic>{
              'id_province': 'p1',
              'name': 'Ha Tinh',
              'description': 'Coastal',
              'cover_image': 'province/p1/cover.jpg',
              'gallery': <String>['province/p1/one.jpg'],
              'avg_rating': 4.6,
              'review_count': 5,
            },
          ],
        };
      },
    ),
    mediaResolver: (String raw) => 'https://media.test/$raw',
  );

  final List<RecommendDestination> result =
      await repository.getPersonalizedProvinces();

  expect(result.single.imagePath, 'https://media.test/province/p1/cover.jpg');
  expect(result.single.gallery, <String>[
    'https://media.test/province/p1/one.jpg',
  ]);
  expect(result.single.reviewCount, 5);
});
```

- [ ] **Step 2: Write the failing Planner province mapper test**

```dart
test('maps a cached old_province R2 key to an absolute URL', () {
  final PlannerProvince province = PlannerProvince.fromReferenceRecord(
    <String, dynamic>{
      'id_province': 'p1',
      'name': 'Ha Tinh',
      'region_code': 'North Central',
      'cover_image': 'province/p1/cover.jpg',
    },
    mediaResolver: (String raw) => 'https://media.test/$raw',
  );

  expect(province.coverImage, 'https://media.test/province/p1/cover.jpg');
});
```

- [ ] **Step 3: Run both tests and confirm missing interfaces**

```powershell
Push-Location frontend
flutter test test/features/recommend/data/recommend_repository_test.dart `
  test/features/planner/data/planner_province_test.dart
Pop-Location
```

Expected: failures for `mediaResolver`, `reviewCount`, and `PlannerProvince`.

- [ ] **Step 4: Normalize all Recommend media in the repository**

Add to `RecommendDestination`:

```dart
final int reviewCount;
```

with constructor default `this.reviewCount = 0` for compatibility with
non-Home call sites.

In `RecommendRepository`, inject:

```dart
typedef RecommendMediaResolver = String Function(String rawValue);

RecommendRepository({
  SupabaseFunctionClient? functionClient,
  RecommendMediaResolver mediaResolver = MediaUrlResolver.resolve,
}) : _functionClient = functionClient ?? SupabaseFunctionClient(),
     _mediaResolver = mediaResolver;
```

Map cover and gallery values through `_mediaResolver`, filter empty results,
and map:

```dart
reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
```

Change the nested factories to accept and forward the same resolver:

```dart
factory ProvinceTopPlace.fromJson(
  Map<String, dynamic> json, {
  RecommendMediaResolver mediaResolver = MediaUrlResolver.resolve,
}) {
  final String cover = mediaResolver(
    json['cover_image']?.toString() ?? '',
  );
  final String gallery = mediaResolver(
    json['gallery_url']?.toString() ?? '',
  );
  return ProvinceTopPlace(
    idPlace: json['id_place'] as String? ?? '',
    name: json['name'] as String? ?? '',
    address: json['address'] as String?,
    coverImage: cover.isEmpty ? null : cover,
    galleryUrl: gallery.isEmpty ? null : gallery,
    averageRating: (json['average_rating'] as num?)?.toDouble(),
    reviewCount: (json['review_count'] as num?)?.toInt(),
    subcategoryName: json['subcategory_name'] as String?,
    tagMatch: (json['tag_match'] as num?)?.toDouble() ?? 0,
  );
}

factory ProvinceDetail.fromJson(
  Map<String, dynamic> json, {
  RecommendMediaResolver mediaResolver = MediaUrlResolver.resolve,
}) {
  final List<Object?> rawPlaces =
      json['top_places'] as List<Object?>? ?? const <Object?>[];
  return ProvinceDetail(
    idProvince: json['id_province'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
    placeCount: (json['place_count'] as num?)?.toInt() ?? 0,
    topPlaces: rawPlaces
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> row) => ProvinceTopPlace.fromJson(
            row,
            mediaResolver: mediaResolver,
          ),
        )
        .toList(growable: false),
  );
}
```

`getTopPlacesForProvince` must call
`ProvinceDetail.fromJson(data, mediaResolver: _mediaResolver)`.

- [ ] **Step 5: Add the Planner province mapper**

Implement:

```dart
typedef PlannerMediaResolver = String Function(String rawValue);

class PlannerProvince {
  const PlannerProvince({
    required this.id,
    required this.name,
    required this.area,
    this.coverImage,
  });

  factory PlannerProvince.fromReferenceRecord(
    Map<String, dynamic> row, {
    PlannerMediaResolver mediaResolver = MediaUrlResolver.resolve,
  }) {
    final String resolved =
        mediaResolver(row['cover_image']?.toString() ?? '').trim();
    return PlannerProvince(
      id: (row['id_province']?.toString() ?? '').trim(),
      name: (row['name']?.toString() ?? '').trim(),
      area: (row['region_code']?.toString() ?? '').trim(),
      coverImage: resolved.isEmpty ? null : resolved,
    );
  }

  final String id;
  final String name;
  final String area;
  final String? coverImage;
}
```

Replace private `_ProvinceItem` in `trip_location_page.dart` with
`PlannerProvince`. Keep the six text-only fallback locations, but do not assign
them fake images.

- [ ] **Step 6: Verify the consuming widgets**

Keep `RecommendWhenResultsPage` and `TripLocationPage` using `Image.network`,
because their repositories now guarantee absolute URLs. Add assertions to the
repository/mapper tests that no returned value equals the raw R2 key.

- [ ] **Step 7: Run focused and existing planner tests**

```powershell
Push-Location frontend
flutter test test/features/recommend/data/recommend_repository_test.dart `
  test/features/planner/data/planner_province_test.dart `
  test/features/planner/presentation/planner_dark_mode_test.dart
Pop-Location
```

Expected: all tests pass.

- [ ] **Step 8: Commit the cross-feature media boundary**

```powershell
git add frontend/lib/features/recommend/domain/recommend_destination.dart `
  frontend/lib/features/recommend/data/recommend_repository.dart `
  frontend/lib/features/planner/data/planner_province.dart `
  frontend/lib/features/planner/presentation/trip_location_page.dart `
  frontend/test/features/recommend/data/recommend_repository_test.dart `
  frontend/test/features/planner/data/planner_province_test.dart
git commit -m "fix: resolve R2 province images before rendering"
```

---

### Task 5: Rank only real personalized candidates

**Files:**
- Create: `frontend/test/features/personalization/data/travel_recommendation_service_test.dart`
- Modify: `frontend/lib/features/personalization/data/travel_recommendation_service.dart`

**Interfaces:**
- Produces:

```dart
static List<RecommendDestination> rankDestinations({
  required UserTravelPreferences preferences,
  required Iterable<RecommendDestination> candidates,
})
```

- [ ] **Step 1: Write failing pure-ranking tests**

Create two real candidates and a food-focused profile:

```dart
final UserTravelPreferences preferences = UserTravelPreferences(
  travelStyles: const <TravelStyle>[TravelStyle.food],
  companions: const <TravelCompanion>[TravelCompanion.solo],
  budgetLevel: BudgetLevel.moderate,
  pace: TravelPace.balanced,
  topics: const <InterestTopic>[InterestTopic.streetFood],
  completedAt: DateTime.utc(2026, 7, 27),
);

RecommendDestination candidate({
  required String id,
  required String description,
  double? avgRating,
}) {
  return RecommendDestination(
    id: id,
    name: id,
    shortDescription: description,
    description: description,
    imagePath: 'https://media.test/$id.jpg',
    rating: 0,
    avgRating: avgRating,
  );
}

test('ranks only supplied candidates by preference match', () {
  final List<RecommendDestination> result =
      TravelRecommendationService.rankDestinations(
        preferences: preferences,
        candidates: <RecommendDestination>[
          candidate(id: 'museum', description: 'history museum'),
          candidate(id: 'street-food', description: 'street food and pho'),
        ],
      );

  expect(result.map((item) => item.id), <String>['street-food', 'museum']);
  expect(result, hasLength(2));
});

test('uses average rating only as a deterministic score tie-breaker', () {
  final List<RecommendDestination> result =
      TravelRecommendationService.rankDestinations(
        preferences: preferences,
        candidates: <RecommendDestination>[
          candidate(id: 'lower', description: 'local', avgRating: 4.1),
          candidate(id: 'higher', description: 'local', avgRating: 4.8),
        ],
      );

  expect(result.first.id, 'higher');
});

test('keeps an empty candidate set empty', () {
  expect(
    TravelRecommendationService.rankDestinations(
      preferences: preferences,
      candidates: const <RecommendDestination>[],
    ),
    isEmpty,
  );
});
```

- [ ] **Step 2: Run the test and verify the missing API**

```powershell
Push-Location frontend
flutter test test/features/personalization/data/travel_recommendation_service_test.dart
Pop-Location
```

Expected: failure because `rankDestinations` does not exist.

- [ ] **Step 3: Implement the pure ranker**

Replace `recommendedDestinations` with:

```dart
static List<RecommendDestination> rankDestinations({
  required UserTravelPreferences preferences,
  required Iterable<RecommendDestination> candidates,
}) {
  final Map<String, int> keywordWeights = _keywordWeights(preferences);
  final List<RecommendDestination> ranked =
      List<RecommendDestination>.from(candidates);

  ranked.sort((RecommendDestination a, RecommendDestination b) {
    final int scoreA = _destinationScore(a, keywordWeights);
    final int scoreB = _destinationScore(b, keywordWeights);
    if (scoreA != scoreB) return scoreB.compareTo(scoreA);

    final int ratingOrder =
        (b.avgRating ?? -1).compareTo(a.avgRating ?? -1);
    if (ratingOrder != 0) return ratingOrder;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return ranked;
}
```

Remove the contribution of `destination.rating` from `_destinationScore`.
Delete the unused `recommendedExploreItems`, `orderedExploreCategories`,
`_exploreScore`, and `_categoryForExplore` methods. Remove production imports
of both mock data files.

- [ ] **Step 4: Run the personalization tests**

```powershell
Push-Location frontend
flutter test test/features/personalization/data/travel_recommendation_service_test.dart `
  test/features/personalization/data/travel_preferences_repository_test.dart
Pop-Location
```

Expected: all tests pass.

- [ ] **Step 5: Commit the pure ranking service**

```powershell
git add frontend/lib/features/personalization/data/travel_recommendation_service.dart `
  frontend/test/features/personalization/data/travel_recommendation_service_test.dart
git commit -m "refactor: rank real travel recommendation candidates"
```

---

### Task 6: Add a testable Home content controller

**Files:**
- Create: `frontend/lib/features/home/application/home_content_controller.dart`
- Create: `frontend/test/features/home/application/home_content_controller_test.dart`

**Interfaces:**
- Produces: `HomeFeaturedLoader`, `HomeCandidateLoader`, `HomeClock`
- Produces: `HomeRefreshOutcome`
- Produces: `HomeContentController.loadInitial()`
- Produces: `HomeContentController.refreshAll()`
- Produces: `HomeContentController.retryFeatured()`
- Produces: `HomeContentController.retryPersonalized()`
- Produces: `HomeContentController.refreshIfStale()`

- [ ] **Step 1: Write failing controller state tests**

Cover initial success, independent failures, stale refresh, retained content,
and concurrent calls:

```dart
HomeFeaturedContent realFeatured() {
  return const HomeFeaturedContent(
    destinations: <Destination>[
      Destination(
        id: 'province-1',
        name: 'Ha Tinh',
        category: 'North Central',
        rating: 4.75,
        reviewCount: 8,
        imagePath: 'https://media.example.test/ha-tinh.jpg',
      ),
    ],
    dishes: <Dish>[],
  );
}

RecommendDestination realCandidate(String id) {
  return RecommendDestination(
    id: id,
    name: 'Ha Tinh',
    shortDescription: 'Coastal province',
    description: 'A real recommendation candidate',
    imagePath: 'https://media.example.test/ha-tinh.jpg',
    rating: 0,
    avgRating: 4.75,
    reviewCount: 8,
  );
}

test('loads featured content and candidates independently', () async {
  final HomeContentController controller = HomeContentController(
    loadFeatured: () async => const HomeFeaturedContent(
      destinations: <Destination>[],
      dishes: <Dish>[],
    ),
    loadCandidates: () async => <RecommendDestination>[
      realCandidate('p1'),
    ],
    clock: () => DateTime.utc(2026, 7, 27, 8),
  );

  await controller.loadInitial();

  expect(controller.featured, isNotNull);
  expect(controller.candidates?.single.id, 'p1');
  expect(controller.featuredError, isNull);
  expect(controller.personalizedError, isNull);
  expect(controller.isInitialLoading, isFalse);
});

test('retains successful featured data after refresh failure', () async {
  int calls = 0;
  final HomeFeaturedContent original = realFeatured();
  final HomeContentController controller = HomeContentController(
    loadFeatured: () async {
      calls += 1;
      if (calls == 1) return original;
      throw StateError('offline');
    },
    loadCandidates: () async => const <RecommendDestination>[],
  );

  await controller.loadInitial();
  final HomeRefreshOutcome outcome = await controller.refreshAll();

  expect(controller.featured, same(original));
  expect(outcome.featuredError, isA<StateError>());
});

test('foreground refresh waits for the two-minute freshness window', () async {
  DateTime now = DateTime.utc(2026, 7, 27, 8);
  int calls = 0;
  final HomeContentController controller = HomeContentController(
    loadFeatured: () async {
      calls += 1;
      return realFeatured();
    },
    loadCandidates: () async => const <RecommendDestination>[],
    clock: () => now,
  );

  await controller.loadInitial();
  now = now.add(const Duration(minutes: 1, seconds: 59));
  await controller.refreshIfStale();
  expect(calls, 1);

  now = now.add(const Duration(seconds: 1));
  await controller.refreshIfStale();
  expect(calls, 2);
});

test('deduplicates concurrent full refresh calls', () async {
  final Completer<HomeFeaturedContent> featured =
      Completer<HomeFeaturedContent>();
  final Completer<List<RecommendDestination>> candidates =
      Completer<List<RecommendDestination>>();
  int featuredCalls = 0;
  int candidateCalls = 0;
  final HomeContentController controller = HomeContentController(
    loadFeatured: () {
      featuredCalls += 1;
      return featured.future;
    },
    loadCandidates: () {
      candidateCalls += 1;
      return candidates.future;
    },
  );

  final Future<HomeRefreshOutcome> first = controller.refreshAll();
  final Future<HomeRefreshOutcome> second = controller.refreshAll();
  expect(identical(first, second), isTrue);

  featured.complete(realFeatured());
  candidates.complete(<RecommendDestination>[realCandidate('p1')]);
  await Future.wait(<Future<HomeRefreshOutcome>>[first, second]);

  expect(featuredCalls, 1);
  expect(candidateCalls, 1);
});
```

- [ ] **Step 2: Run the test and verify the controller is missing**

```powershell
Push-Location frontend
flutter test test/features/home/application/home_content_controller_test.dart
Pop-Location
```

Expected: failure because the application file and types do not exist.

- [ ] **Step 3: Implement the controller**

Use the following public shape:

```dart
typedef HomeFeaturedLoader = Future<HomeFeaturedContent> Function();
typedef HomeCandidateLoader =
    Future<List<RecommendDestination>> Function();
typedef HomeClock = DateTime Function();

class HomeRefreshOutcome {
  const HomeRefreshOutcome({
    this.featuredError,
    this.personalizedError,
  });

  final Object? featuredError;
  final Object? personalizedError;
  bool get hasError =>
      featuredError != null || personalizedError != null;
}

class HomeContentController extends ChangeNotifier {
  HomeContentController({
    required HomeFeaturedLoader loadFeatured,
    required HomeCandidateLoader loadCandidates,
    HomeClock? clock,
    Duration freshnessWindow = const Duration(minutes: 2),
  });

  HomeFeaturedContent? get featured;
  List<RecommendDestination>? get candidates;
  Object? get featuredError;
  Object? get personalizedError;
  bool get isInitialLoading;
  bool get isRefreshing;

  Future<HomeRefreshOutcome> loadInitial();
  Future<HomeRefreshOutcome> refreshAll();
  Future<Object?> retryFeatured();
  Future<Object?> retryPersonalized();
  Future<HomeRefreshOutcome?> refreshIfStale();
}
```

Implementation rules:

- `loadInitial` sets initial loading, invokes both loaders independently, then
  clears loading.
- A failed loader sets only its own error.
- A successful loader atomically replaces only its own data.
- `refreshAll` retains old successful values on errors.
- `_activeRefresh` returns the same in-flight future to concurrent callers.
- The featured success timestamp drives the two-minute foreground window.
- State changes always call `notifyListeners()`; all methods remain safe when
  invoked before the first listener is attached.

- [ ] **Step 4: Run the controller tests**

```powershell
Push-Location frontend
flutter test test/features/home/application/home_content_controller_test.dart
Pop-Location
```

Expected: all tests pass.

- [ ] **Step 5: Commit the controller**

```powershell
git add frontend/lib/features/home/application/home_content_controller.dart `
  frontend/test/features/home/application/home_content_controller_test.dart
git commit -m "feat: add Home refresh state controller"
```

---

### Task 7: Integrate loading, retry, pull refresh, and real personalization into Home

**Files:**
- Create: `frontend/lib/features/home/presentation/widgets/home_content_state.dart`
- Create: `frontend/test/features/home/presentation/widgets/home_content_state_test.dart`
- Create: `frontend/test/features/home/presentation/home_page_refresh_test.dart`
- Modify: `frontend/lib/features/home/presentation/home_page.dart`

**Interfaces:**
- `HomePage({HomeContentController? contentController})`
- Widget keys:
  - `home-refresh`
  - `home-destinations-loading`
  - `home-destinations-error`
  - `home-destinations-empty`
  - `home-dishes-loading`
  - `home-picked-error`

- [ ] **Step 1: Write failing loading/error widget tests**

Test the focused state widgets without pumping the complete Home page:

```dart
testWidgets('error state exposes its retry action', (
  WidgetTester tester,
) async {
  int retries = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeContentError(
          key: const Key('home-destinations-error'),
          message: 'Could not load destinations.',
          onRetry: () => retries += 1,
        ),
      ),
    ),
  );

  await tester.tap(find.text('Retry'));
  expect(retries, 1);
});

testWidgets('skeleton exposes a stable loading key', (
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: HomeRecommendationSkeleton(
          key: Key('home-destinations-loading'),
        ),
      ),
    ),
  );

  expect(find.byKey(const Key('home-destinations-loading')), findsOneWidget);
});
```

- [ ] **Step 2: Write the failing Home refresh smoke test**

Inject a controller with completer-backed loaders:

```dart
HomeFeaturedContent realFeatured() {
  return const HomeFeaturedContent(
    destinations: <Destination>[
      Destination(
        id: 'province-1',
        name: 'Ha Tinh',
        category: 'North Central',
        rating: 4.75,
        reviewCount: 8,
        imagePath: 'https://media.example.test/ha-tinh.jpg',
      ),
    ],
    dishes: <Dish>[],
  );
}

testWidgets('pull refresh invokes real featured and candidate loaders', (
  WidgetTester tester,
) async {
  int featuredCalls = 0;
  int candidateCalls = 0;
  final HomeContentController controller = HomeContentController(
    loadFeatured: () async {
      featuredCalls += 1;
      return realFeatured();
    },
    loadCandidates: () async {
      candidateCalls += 1;
      return const <RecommendDestination>[];
    },
  );

  await tester.pumpWidget(
    MaterialApp(home: HomePage(contentController: controller)),
  );
  await tester.pumpAndSettle();

  await tester.drag(
    find.byKey(const Key('home-refresh')),
    const Offset(0, 500),
  );
  await tester.pumpAndSettle();

  expect(featuredCalls, 2);
  expect(candidateCalls, 2);
});
```

Initialize the Supabase singleton in this test file only if an existing Home
dependency touches it despite controller injection:

```dart
setUpAll(() async {
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'test-anon-key',
  );
});
```

- [ ] **Step 3: Run both new test files and verify missing widgets/injection**

```powershell
Push-Location frontend
flutter test test/features/home/presentation/widgets/home_content_state_test.dart `
  test/features/home/presentation/home_page_refresh_test.dart
Pop-Location
```

Expected: failures because the state widgets and injected controller do not exist.

- [ ] **Step 4: Implement focused state widgets**

`home_content_state.dart` contains:

```dart
class HomeRecommendationSkeleton extends StatelessWidget {
  const HomeRecommendationSkeleton({super.key});
}

class HomeContentError extends StatelessWidget {
  const HomeContentError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;
}

class HomeContentEmpty extends StatelessWidget {
  const HomeContentEmpty({
    super.key,
    required this.message,
  });

  final String message;
}
```

Use existing Home colors, card radius, and theme-aware surfaces. The skeleton
contains four fixed card shapes but no fake titles, ratings, or image paths.

- [ ] **Step 5: Inject and own the controller correctly**

Update `HomePage`:

```dart
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.contentController});

  final HomeContentController? contentController;
}
```

In state:

```dart
late final HomeContentController _contentController;
late final bool _ownsContentController;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _ownsContentController = widget.contentController == null;
  _contentController = widget.contentController ??
      HomeContentController(
        loadFeatured: () => HomeRepository().fetchFeaturedContent(),
        loadCandidates: () =>
            RecommendRepository().getPersonalizedProvinces(),
      );
  unawaited(_contentController.loadInitial());
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  if (_ownsContentController) _contentController.dispose();
  _galaxyTwinkleController.dispose();
  super.dispose();
}
```

Add `WidgetsBindingObserver` to the state mixins and implement:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    unawaited(_refreshIfStale());
  }
}
```

- [ ] **Step 6: Replace mock-backed sections with controller states**

Remove `_destinations`, `_dishes`, `_loadFeaturedContent`, and the
`home_mock_data.dart` import.

Wrap the scroll view in:

```dart
RefreshIndicator(
  key: const Key('home-refresh'),
  onRefresh: _refreshAll,
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    // existing content
  ),
)
```

Use `AnimatedBuilder(animation: _contentController, ...)` for destinations and
dishes:

- `featured == null && featuredError == null`: skeleton.
- `featured == null && featuredError != null`: keyed error + Retry.
- successful empty list: keyed empty state.
- successful non-empty list: existing `RecommendationSection`.

On refresh error with existing data:

```dart
final HomeRefreshOutcome outcome = await _contentController.refreshAll();
if (!mounted || !outcome.hasError) return;
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Some Home content could not be refreshed.')),
);
```

- [ ] **Step 7: Replace "Picked for you" candidates**

Inside the existing travel-preference `ListenableBuilder`:

```dart
final List<RecommendDestination> picked =
    _contentController.candidates == null
        ? const <RecommendDestination>[]
        : TravelRecommendationService.rankDestinations(
            preferences: preferences,
            candidates: _contentController.candidates!,
          ).take(4).toList(growable: false);
```

State rules:

- candidates loading: show the skeleton after the preference summary.
- candidate error: show `HomeContentError` with key `home-picked-error` and
  `retryPersonalized`.
- successful empty candidates: omit the recommendation section.
- successful candidates: render the top four.

Pass `d.avgRating` and `d.reviewCount` to the card. Do not use `d.rating` as a
star rating.

- [ ] **Step 8: Add foreground-refresh coverage**

In `home_page_refresh_test.dart`, advance the injected clock by two minutes,
dispatch:

```dart
tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
await tester.pumpAndSettle();
```

Expect the loader counts to increase. Repeat with one minute elapsed and
expect no increase.

- [ ] **Step 9: Run Home presentation tests**

```powershell
Push-Location frontend
flutter test test/features/home/presentation/widgets/home_banner_test.dart `
  test/features/home/presentation/widgets/home_content_state_test.dart `
  test/features/home/presentation/widgets/recommendation_card_test.dart `
  test/features/home/presentation/home_page_refresh_test.dart
Pop-Location
```

Expected: all tests pass and the banner test confirms the static banner remains.

- [ ] **Step 10: Commit the Home integration**

```powershell
git add frontend/lib/features/home/presentation/home_page.dart `
  frontend/lib/features/home/presentation/widgets/home_content_state.dart `
  frontend/test/features/home/presentation/widgets/home_content_state_test.dart `
  frontend/test/features/home/presentation/home_page_refresh_test.dart
git commit -m "feat: refresh Home from real data"
```

---

### Task 8: Separate static feature navigation from mock content and verify

**Files:**
- Create: `frontend/lib/features/home/data/home_feature_data.dart`
- Move: `frontend/test/features/home/data/home_mock_data_test.dart` to `frontend/test/features/home/data/home_feature_data_test.dart`
- Delete: `frontend/lib/features/home/data/home_mock_data.dart`
- Modify: imports referring to `homeFeatures`

**Interfaces:**
- Produces: `const List<FeatureItem> homeFeatures`
- Removes production Home destination/dish mock constants

- [ ] **Step 1: Move only valid static navigation data**

Create `home_feature_data.dart` containing the existing eight `FeatureItem`
records and their routes. Do not copy `mockDestinations` or `mockDishes`.

Rename the test and update its import:

```dart
import 'package:hellovietnam/features/home/data/home_feature_data.dart';
```

Keep assertions for the eight routes and remove assertions that require mock
destination or dish cards.

- [ ] **Step 2: Delete the old mock file and update Home import**

```powershell
git mv frontend/test/features/home/data/home_mock_data_test.dart `
  frontend/test/features/home/data/home_feature_data_test.dart
```

Delete `frontend/lib/features/home/data/home_mock_data.dart` using
`apply_patch`, then import `home_feature_data.dart` from `home_page.dart`.

- [ ] **Step 3: Run targeted tests and the production mock scan**

```powershell
Push-Location frontend
flutter test test/features/home/data/home_feature_data_test.dart `
  test/features/home/data/home_repository_test.dart `
  test/features/personalization/data/travel_recommendation_service_test.dart

rg -n "home_mock_data|mockDestinations|mockDishes|picsum" lib/features/home
rg -n "recommend_mock_data|explore_mock_data" `
  lib/features/personalization/data/travel_recommendation_service.dart
Pop-Location
```

Expected: tests pass; both `rg` commands return no matches.

- [ ] **Step 4: Run formatter and full Flutter verification**

```powershell
Push-Location frontend
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
Pop-Location
```

Expected:

- `dart format` exits 0;
- `flutter analyze` reports no issues;
- the full test suite passes;
- debug APK build exits 0.

- [ ] **Step 5: Rerun the SQL regression test**

```powershell
psql $env:DATABASE_URL -v ON_ERROR_STOP=1 `
  -f backend/supabase/tests/home_featured_content_rpc_test.sql
```

Expected: exit code 0.

- [ ] **Step 6: Inspect the final diff and protect unrelated files**

```powershell
git status --short
git diff --check
git diff --name-only HEAD
```

Expected: only files listed in Tasks 1–8 are part of implementation commits;
the pre-existing report, architecture, VS Code, and generated diagram changes
remain unstaged and untouched.

- [ ] **Step 7: Commit the cleanup and verification result**

```powershell
git add -A -- frontend/lib/features/home/data `
  frontend/lib/features/home/presentation/home_page.dart `
  frontend/test/features/home/data
git commit -m "chore: remove production Home mock content"
```

- [ ] **Step 8: Review the complete branch**

Run:

```powershell
git log --oneline --decorate -10
git status --short --branch
```

Confirm the eight implementation tasks are represented by focused commits and
no required work from the approved spec remains.
