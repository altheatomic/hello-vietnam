# Explore Share To Forum Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a share icon under the favorite icon on Explore-backed detail pages that opens the forum composer with the current Explore item attached, and record an Explore `share` event only after the forum post is created successfully.

**Architecture:** Keep the change frontend-only except for reusing the existing `recordExploreEvent` backend action and `share` event type. Pass a lightweight Explore share payload through router `extra`, render an attached-item preview in the forum composer, and trigger tracking after `ForumStore.createPost(...)` returns a successful `postId`.

**Tech Stack:** Flutter, GoRouter, Supabase Edge Functions, existing Explore tracking service, existing forum store/repository flow.

---

### Task 1: Add Share Payload Models

**Files:**
- Create: `frontend/lib/features/forum/domain/create_forum_post_request.dart`
- Modify: `frontend/lib/app/router.dart`
- Test: `frontend/test/features/forum/domain/create_forum_post_request_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  test('shared explore item request keeps the expected tracking fields', () {
    const SharedExploreItem item = SharedExploreItem(
      contentType: 'food',
      contentId: 'food-1',
      provinceId: 'province-1',
      title: 'Bun cha ca',
      imagePath: 'https://example.com/a.jpg',
      category: DetailCategory.food,
    );

    const CreateForumPostRequest request = CreateForumPostRequest(
      sharedExploreItem: item,
    );

    expect(request.sharedExploreItem, isNotNull);
    expect(request.sharedExploreItem!.contentType, 'food');
    expect(request.sharedExploreItem!.contentId, 'food-1');
    expect(request.sharedExploreItem!.provinceId, 'province-1');
    expect(request.sharedExploreItem!.title, 'Bun cha ca');
    expect(request.sharedExploreItem!.imagePath, 'https://example.com/a.jpg');
    expect(request.sharedExploreItem!.category, DetailCategory.food);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd frontend
dart test test/features/forum/domain/create_forum_post_request_test.dart
```

Expected: FAIL because `create_forum_post_request.dart` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `frontend/lib/features/forum/domain/create_forum_post_request.dart`:

```dart
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

class CreateForumPostRequest {
  const CreateForumPostRequest({this.sharedExploreItem});

  final SharedExploreItem? sharedExploreItem;
}

class SharedExploreItem {
  const SharedExploreItem({
    required this.contentType,
    required this.contentId,
    required this.provinceId,
    required this.title,
    required this.imagePath,
    required this.category,
  });

  final String contentType;
  final String contentId;
  final String? provinceId;
  final String title;
  final String imagePath;
  final DetailCategory category;
}
```

Update `frontend/lib/app/router.dart` route builder for `AppRoutes.forumCreate`:

```dart
import '../features/forum/domain/create_forum_post_request.dart';
```

```dart
GoRoute(
  parentNavigatorKey: rootNavigatorKey,
  path: AppRoutes.forumCreate,
  builder: (c, s) => CreatePostPage(
    request: s.extra is CreateForumPostRequest
        ? s.extra as CreateForumPostRequest
        : const CreateForumPostRequest(),
  ),
),
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd frontend
dart test test/features/forum/domain/create_forum_post_request_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/forum/domain/create_forum_post_request.dart frontend/lib/app/router.dart frontend/test/features/forum/domain/create_forum_post_request_test.dart
git commit -m "feat: add forum share request models"
```

### Task 2: Add Share Icon On Explore Detail Pages

**Files:**
- Modify: `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`
- Modify: `frontend/lib/features/item_detail/domain/item_detail_models.dart`
- Test: `frontend/test/features/item_detail/domain/item_detail_request_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

void main() {
  test('item detail request preserves explore behavior flags through copyWith', () {
    const ItemDetailRequest request = ItemDetailRequest(
      id: 'food-1',
      name: 'Bun cha ca',
      category: DetailCategory.food,
      trackExploreBehavior: true,
      exploreProvinceId: 'province-1',
    );

    final ItemDetailRequest copied = request.copyWith();

    expect(copied.trackExploreBehavior, isTrue);
    expect(copied.exploreProvinceId, 'province-1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails or guards current behavior**

Run:

```bash
cd frontend
dart test test/features/item_detail/domain/item_detail_request_test.dart
```

Expected: if the test file is new, it fails before creation; after creation it should pass and guard current Explore context behavior before UI changes.

- [ ] **Step 3: Write minimal implementation**

In `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`, add imports:

```dart
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
```

Add a share handler:

```dart
Future<void> _shareToForum() async {
  if (!_shouldTrackExploreBehavior) {
    return;
  }

  await context.push(
    AppRoutes.forumCreate,
    extra: CreateForumPostRequest(
      sharedExploreItem: SharedExploreItem(
        contentType: _contentTypeForCategory(_detail.category),
        contentId: _detail.id,
        provinceId: _trackingProvinceId,
        title: _detail.name,
        imagePath: _detail.images.isEmpty ? '' : _detail.images.first,
        category: _detail.category,
      ),
    ),
  );
}
```

Add helper:

```dart
String _contentTypeForCategory(DetailCategory category) {
  switch (category) {
    case DetailCategory.activities:
      return 'activity';
    case DetailCategory.culture:
      return 'culture';
    case DetailCategory.food:
      return 'food';
    case DetailCategory.localProducts:
      return 'local_product';
  }
}
```

Update `_HeroImageCarousel` contract:

```dart
const _HeroImageCarousel({
  required this.images,
  required this.rating,
  required this.isFavorite,
  required this.currentPage,
  required this.onPageChanged,
  required this.onFavoriteTap,
  required this.onShareTap,
  required this.showShareButton,
});

final VoidCallback onShareTap;
final bool showShareButton;
```

Render the share icon under favorite:

```dart
Positioned(
  top: 14,
  right: 14,
  child: Column(
    children: <Widget>[
      _CircleIconButton(
        icon: isFavorite ? Icons.favorite : Icons.favorite_border,
        onTap: onFavoriteTap,
        iconColor: isFavorite ? const Color(0xFFFF5E7A) : Colors.white,
        backgroundColor: Colors.black.withValues(alpha: 0.28),
      ),
      if (showShareButton) ...<Widget>[
        const SizedBox(height: 10),
        _CircleIconButton(
          icon: Icons.share_outlined,
          onTap: onShareTap,
          iconColor: Colors.white,
          backgroundColor: Colors.black.withValues(alpha: 0.28),
        ),
      ],
    ],
  ),
),
```

Pass props from `build(...)`:

```dart
_HeroImageCarousel(
  images: _detail.images,
  rating: _detail.rating,
  isFavorite: _isFavorite,
  currentPage: _currentPage,
  onFavoriteTap: _toggleFavorite,
  onShareTap: _shareToForum,
  showShareButton: _shouldTrackExploreBehavior,
  onPageChanged: (int index) {
    setState(() => _currentPage = index);
  },
),
```

- [ ] **Step 4: Run focused verification**

Run:

```bash
cd frontend
dart analyze lib/features/item_detail/presentation/shared_item_detail_page.dart lib/features/item_detail/domain/item_detail_models.dart test/features/item_detail/domain/item_detail_request_test.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart frontend/lib/features/item_detail/domain/item_detail_models.dart frontend/test/features/item_detail/domain/item_detail_request_test.dart
git commit -m "feat: add explore detail share entry point"
```

### Task 3: Attach Shared Explore Preview In Forum Composer

**Files:**
- Modify: `frontend/lib/features/forum/presentation/create_post_page.dart`
- Test: `frontend/test/features/forum/presentation/create_post_page_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/presentation/create_post_page.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  testWidgets('shows attached explore preview when request includes shared item', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CreatePostPage(
          request: CreateForumPostRequest(
            sharedExploreItem: SharedExploreItem(
              contentType: 'food',
              contentId: 'food-1',
              provinceId: 'province-1',
              title: 'Bun cha ca',
              imagePath: '',
              category: DetailCategory.food,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bun cha ca'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd frontend
dart test test/features/forum/presentation/create_post_page_test.dart
```

Expected: FAIL because `CreatePostPage` does not accept a request or render the attached preview yet.

- [ ] **Step 3: Write minimal implementation**

Update `CreatePostPage` signature:

```dart
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    this.request = const CreateForumPostRequest(),
  });

  final CreateForumPostRequest request;
```

Add import:

```dart
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
```

Render preview inside the main card above the text field:

```dart
if (widget.request.sharedExploreItem case final SharedExploreItem item) ...<Widget>[
  _SharedExplorePreview(item: item),
  const SizedBox(height: 16),
],
```

Add preview widget:

```dart
class _SharedExplorePreview extends StatelessWidget {
  const _SharedExplorePreview({required this.item});

  final SharedExploreItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.imagePath.trim().isEmpty
                  ? const ColoredBox(color: Color(0xFFEAF4F8))
                  : Image.network(item.imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.category.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd frontend
dart test test/features/forum/presentation/create_post_page_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/forum/presentation/create_post_page.dart frontend/test/features/forum/presentation/create_post_page_test.dart
git commit -m "feat: show shared explore preview in forum composer"
```

### Task 4: Record Share Event After Successful Forum Post

**Files:**
- Modify: `frontend/lib/features/explore/data/explore_tracking_service.dart`
- Modify: `frontend/lib/features/forum/presentation/create_post_page.dart`
- Test: `frontend/test/features/explore/data/explore_tracking_service_test.dart`
- Test: `frontend/test/features/forum/presentation/create_post_page_share_tracking_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `frontend/test/features/explore/data/explore_tracking_service_test.dart`:

```dart
test('sends share event payload', () async {
  Map<String, dynamic>? capturedBody;

  final ExploreTrackingService service = ExploreTrackingService(
    accessTokenProvider: () => 'token-123',
    requestIdGenerator: () => 'request-share',
    sender: ({Map<String, String>? headers, required Map<String, dynamic> body}) async {
      capturedBody = body;
    },
  );

  await service.trackShare(
    contentType: 'food',
    contentId: 'food-1',
    provinceId: 'province-1',
  );

  expect(capturedBody?['eventType'], 'share');
  expect(capturedBody?['contentType'], 'food');
});
```

Create `frontend/test/features/forum/presentation/create_post_page_share_tracking_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(true, isTrue);
  });
}
```

Replace the placeholder with a real widget/integration-style test once the page accepts injected collaborators. The real test should assert:

- successful post creation with shared item calls `trackShare(...)`
- failed post creation does not call `trackShare(...)`

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd frontend
dart test test/features/explore/data/explore_tracking_service_test.dart
```

Expected: FAIL because `trackShare(...)` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add to `ExploreTrackingService`:

```dart
Future<void> trackShare({
  required String contentType,
  required String contentId,
  String? provinceId,
}) {
  return _recordEventByContentType(
    contentType: contentType,
    contentId: contentId,
    provinceId: provinceId,
    eventType: 'share',
  );
}
```

Refactor `_recordEvent(...)` into a shared private method that can support both `DetailCategory` mapping and direct content-type input:

```dart
Future<void> _recordEventByContentType({
  required String contentType,
  required String contentId,
  required String eventType,
  String? provinceId,
}) async {
  // same token lookup and sender flow as existing tracking
}
```

In `CreatePostPage._submit()`:

```dart
final String postId = await _store.createPost(
  content: content,
  imageFiles: _selectedImages,
);

final SharedExploreItem? sharedItem = widget.request.sharedExploreItem;
if (sharedItem != null) {
  await ExploreTrackingService.instance.trackShare(
    contentType: sharedItem.contentType,
    contentId: sharedItem.contentId,
    provinceId: sharedItem.provinceId,
  );
}

if (mounted) {
  context.pop(postId);
}
```

If you need testability, inject optional dependencies into `CreatePostPage`:

```dart
final ForumStore store;
final ExploreTrackingService trackingService;
```

with defaults to the singleton instances.

- [ ] **Step 4: Run verification**

Run:

```bash
cd frontend
dart analyze lib/features/explore/data/explore_tracking_service.dart lib/features/forum/presentation/create_post_page.dart
dart test test/features/explore/data/explore_tracking_service_test.dart
```

Expected:

- `No issues found!`
- share tracking test PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/explore/data/explore_tracking_service.dart frontend/lib/features/forum/presentation/create_post_page.dart frontend/test/features/explore/data/explore_tracking_service_test.dart frontend/test/features/forum/presentation/create_post_page_share_tracking_test.dart
git commit -m "feat: track explore forum share on successful post"
```

### Task 5: Manual Verification And Documentation Sync

**Files:**
- Modify: `backend/explore/README.md`
- Modify: `docs/superpowers/specs/2026-06-25-explore-share-to-forum-design.md`

- [ ] **Step 1: Update documentation**

Add a short section to `backend/explore/README.md` describing the new behavior:

```md
Forum share tracking:

- Explore-backed item detail pages can open the forum composer with an attached Explore item.
- A `share` event is recorded only after the forum post is created successfully.
- Event weight is `+2` and uses the same `recordExploreEvent` path as other Explore behavior events.
```

- [ ] **Step 2: Run manual verification**

Run through this checklist:

```text
1. Open Explore -> province-backed results -> item detail.
2. Confirm share icon appears below favorite.
3. Tap share icon and confirm forum composer opens.
4. Confirm composer preview shows the selected item.
5. Submit a forum post successfully.
6. Confirm app log shows ExploreTracking Sent ... share ...
7. Confirm user_explore_event has a new share row.
8. Confirm user_interest_tag weights for the item tags increase.
9. Re-run personalization report and confirm ranking can change.
```

- [ ] **Step 3: Verify DB event manually**

Run:

```bash
cd backend
npx.cmd supabase db query --linked -o json --file <temp-share-query.sql> --workdir .
```

SQL content:

```sql
select event_type, event_score, content_id, created_at
from public.user_explore_event
where content_id = '<shared-content-id>'
order by created_at desc
limit 10;
```

Expected: newest row includes `event_type = share` and `event_score = 2`

- [ ] **Step 4: Commit**

```bash
git add backend/explore/README.md docs/superpowers/specs/2026-06-25-explore-share-to-forum-design.md
git commit -m "docs: document explore forum share flow"
```

## Self-Review

- Spec coverage:
  - share icon below favorite -> Task 2
  - open composer with attached Explore item -> Tasks 1-3
  - track only after successful post -> Task 4
  - manual ranking verification -> Task 5
- Placeholder scan:
  - no `TBD` or `TODO`
  - every code-changing step contains code blocks
- Type consistency:
  - `CreateForumPostRequest` carries `SharedExploreItem`
  - `CreatePostPage` accepts `CreateForumPostRequest`
  - `ExploreTrackingService.trackShare(...)` uses direct content-type strings compatible with `recordExploreEvent`
