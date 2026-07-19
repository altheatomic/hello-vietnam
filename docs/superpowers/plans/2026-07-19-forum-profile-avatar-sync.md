# Forum Profile Avatar Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a successful Profile avatar upload or removal update every current-user avatar in Forum immediately while keeping `user_account.avatar` as the only persisted source.

**Architecture:** `AuthRepository` publishes a typed avatar-change event after persistence succeeds. `ForumStore` subscribes once, patches all cached current-user author references synchronously, notifies the UI, and starts a non-blocking snapshot refresh. A focused URL normalizer keeps legacy storage paths compatible with the shared Cloudflare public URL.

**Tech Stack:** Flutter, Dart, ChangeNotifier, broadcast streams, Supabase, flutter_test.

## Global Constraints

- Do not add a database column, table, migration, or second persisted avatar source.
- Local Forum UI synchronization must happen before the background snapshot refresh completes.
- Preserve the current cached Forum navigation behavior and existing user changes in the worktree.
- Use `assets/images/avatar/avatar.jpg` when the Forum avatar value is empty or the network image fails.

---

### Task 1: Typed Current-User Avatar Events

**Files:**
- Create: `frontend/lib/core/auth/current_user_avatar_change.dart`
- Create: `frontend/test/core/auth/current_user_avatar_change_test.dart`
- Modify: `frontend/lib/core/auth/auth_repository.dart`

**Interfaces:**
- Produces: `CurrentUserAvatarChange({required String userId, required String? avatarUrl})`.
- Produces: `CurrentUserAvatarChanges.instance.stream` and `publish(CurrentUserAvatarChange change)`.
- `AuthRepository.uploadCurrentUserAvatar` publishes the uploaded public URL after `user_account.avatar` is saved.
- `AuthRepository.clearCurrentUserAvatar` publishes `avatarUrl: null` after `user_account.avatar` is cleared.

- [ ] **Step 1: Write the failing event-stream tests**

```dart
test('publishes the uploaded avatar for the authenticated user', () async {
  final CurrentUserAvatarChanges changes = CurrentUserAvatarChanges.test();
  final Future<CurrentUserAvatarChange> next = changes.stream.first;

  changes.publish(
    const CurrentUserAvatarChange(
      userId: 'user-1',
      avatarUrl: 'https://media.example/avatar.jpg',
    ),
  );

  expect(
    await next,
    isA<CurrentUserAvatarChange>()
        .having((change) => change.userId, 'userId', 'user-1')
        .having(
          (change) => change.avatarUrl,
          'avatarUrl',
          'https://media.example/avatar.jpg',
        ),
  );
  await changes.dispose();
});

test('publishes null when the uploaded avatar is removed', () async {
  final CurrentUserAvatarChanges changes = CurrentUserAvatarChanges.test();
  final Future<CurrentUserAvatarChange> next = changes.stream.first;
  changes.publish(
    const CurrentUserAvatarChange(userId: 'user-1', avatarUrl: null),
  );
  expect((await next).avatarUrl, isNull);
  await changes.dispose();
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run: `cd frontend && flutter test test/core/auth/current_user_avatar_change_test.dart`

Expected: FAIL because `current_user_avatar_change.dart`, `CurrentUserAvatarChange`, and `CurrentUserAvatarChanges` do not exist.

- [ ] **Step 3: Implement the minimal broadcast event channel**

```dart
import 'dart:async';

class CurrentUserAvatarChange {
  const CurrentUserAvatarChange({required this.userId, required this.avatarUrl});

  final String userId;
  final String? avatarUrl;
}

class CurrentUserAvatarChanges {
  CurrentUserAvatarChanges._();
  CurrentUserAvatarChanges.test();

  static final CurrentUserAvatarChanges instance = CurrentUserAvatarChanges._();
  final StreamController<CurrentUserAvatarChange> _controller =
      StreamController<CurrentUserAvatarChange>.broadcast();

  Stream<CurrentUserAvatarChange> get stream => _controller.stream;
  void publish(CurrentUserAvatarChange change) => _controller.add(change);
  Future<void> dispose() => _controller.close();
}
```

In `AuthRepository`, publish only after the corresponding `user_account` write succeeds:

```dart
CurrentUserAvatarChanges.instance.publish(
  CurrentUserAvatarChange(userId: userId, avatarUrl: uploaded.url),
);
```

```dart
CurrentUserAvatarChanges.instance.publish(
  CurrentUserAvatarChange(userId: userId, avatarUrl: null),
);
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `cd frontend && flutter test test/core/auth/current_user_avatar_change_test.dart`

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit the event channel**

```bash
git add frontend/lib/core/auth/current_user_avatar_change.dart frontend/lib/core/auth/auth_repository.dart frontend/test/core/auth/current_user_avatar_change_test.dart
git commit -m "feat: publish profile avatar changes"
```

---

### Task 2: Immediate ForumStore Synchronization

**Files:**
- Modify: `frontend/lib/features/forum/data/forum_store.dart`
- Modify: `frontend/lib/features/forum/domain/forum_models.dart`
- Modify: `frontend/test/features/forum/data/forum_store_test.dart`

**Interfaces:**
- Consumes: `Stream<CurrentUserAvatarChange>` from Task 1.
- Produces: optional `avatarChanges` constructor dependency in `ForumStore.test`.
- Produces: `ForumNotificationItem.copyWith({ForumAuthor? actor, ...})`.

- [ ] **Step 1: Write a failing store test for immediate propagation**

Create a snapshot containing current-user profile, post, comment, and notification actor with `avatar-old`. Inject a broadcast controller into `ForumStore.test`, load the snapshot, publish `avatar-new`, and deliberately leave the repository's second `loadSnapshot` pending.

```dart
avatarChanges.add(
  const CurrentUserAvatarChange(userId: 'user-1', avatarUrl: 'avatar-new'),
);
await pumpEventQueue();

expect(store.currentUserAuthor.avatarUrl, 'avatar-new');
expect(store.forYouPosts.single.author.avatarUrl, 'avatar-new');
expect(store.commentsForPost('post-1').single.author.avatarUrl, 'avatar-new');
expect(store.notifications.single.actor.avatarUrl, 'avatar-new');
expect(repository.pendingRefreshCompleted, isFalse);
```

Add companion assertions that `avatarUrl: null` becomes `''` and a change for `user-2` does not alter `user-1`.

- [ ] **Step 2: Run the focused store test and verify RED**

Run: `cd frontend && flutter test test/features/forum/data/forum_store_test.dart`

Expected: FAIL because `ForumStore.test` cannot accept `avatarChanges` and cached author references are unchanged.

- [ ] **Step 3: Implement minimal store subscription and propagation**

Subscribe once from `init` and route matching current-user events to `_applyCurrentUserAvatar`:

```dart
void _applyCurrentUserAvatar(CurrentUserAvatarChange change) {
  if (change.userId.isEmpty || change.userId != _currentUserId) return;
  final ForumUserProfile? profile = _currentUserProfile;
  if (profile == null) return;

  final ForumAuthor updatedAuthor = profile.author.copyWith(
    avatarUrl: change.avatarUrl?.trim() ?? '',
  );
  _currentUserProfile = profile.copyWith(author: updatedAuthor);
  _profilesById[_currentUserId] = _currentUserProfile!;
  _syncAuthorAcrossPosts(updatedAuthor);
  _notifications = _notifications
      .map((item) => item.actor.id == _currentUserId
          ? item.copyWith(actor: updatedAuthor)
          : item)
      .toList(growable: false);
  notifyListeners();
  unawaited(refresh(notifyLoading: false));
}
```

Add `ForumNotificationItem.copyWith` using the existing model conventions. Ensure `_clear` does not create another subscription; authentication and avatar subscriptions are each installed only once.

- [ ] **Step 4: Run the focused store tests and verify GREEN**

Run: `cd frontend && flutter test test/features/forum/data/forum_store_test.dart`

Expected: PASS for preload and all avatar synchronization cases.

- [ ] **Step 5: Commit Forum synchronization**

```bash
git add frontend/lib/features/forum/data/forum_store.dart frontend/lib/features/forum/domain/forum_models.dart frontend/test/features/forum/data/forum_store_test.dart
git commit -m "feat: sync profile avatar across forum"
```

---

### Task 3: Legacy URL Normalization and Avatar Fallback

**Files:**
- Create: `frontend/lib/features/forum/data/forum_avatar_url.dart`
- Create: `frontend/test/features/forum/data/forum_avatar_url_test.dart`
- Modify: `frontend/lib/features/forum/data/forum_repository.dart`
- Modify: `frontend/lib/features/forum/presentation/widgets/forum_widgets.dart`
- Modify: `frontend/test/features/forum/presentation/forum_share_post_widgets_test.dart`

**Interfaces:**
- Produces: `resolveForumAvatarUrl(String? value, {CloudflareMediaRepository? mediaRepository}) -> String`.
- `ForumRepository._profileFromRow` consumes the resolver for `row['avatar']`.
- `ForumAvatar` renders `assets/images/avatar/avatar.jpg` for an empty or failed network URL.

- [ ] **Step 1: Write failing URL and widget fallback tests**

```dart
test('keeps absolute avatar URLs', () {
  expect(resolveForumAvatarUrl('https://example.com/a.jpg'),
      'https://example.com/a.jpg');
});

test('turns legacy avatar keys into Cloudflare public URLs', () {
  expect(
    resolveForumAvatarUrl('avatars/user-1/a.jpg'),
    '${Env.cloudflareMediaPublicBaseUrl}/avatars/user-1/a.jpg',
  );
});
```

Pump `ForumAvatar(imageUrl: '', size: 40)` and assert an `Image` backed by `AssetImage('assets/images/avatar/avatar.jpg')` is present.

- [ ] **Step 2: Run focused tests and verify RED**

Run: `cd frontend && flutter test test/features/forum/data/forum_avatar_url_test.dart test/features/forum/presentation/forum_share_post_widgets_test.dart`

Expected: FAIL because the resolver does not exist and an empty Forum avatar uses `Image.network`.

- [ ] **Step 3: Implement the resolver and fallback**

```dart
String resolveForumAvatarUrl(
  String? value, {
  CloudflareMediaRepository? mediaRepository,
}) {
  final String avatar = value?.trim() ?? '';
  if (avatar.isEmpty || avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return avatar;
  }
  return (mediaRepository ?? CloudflareMediaRepository())
          .publicUrlForKey(avatar) ??
      '';
}
```

Use the resolver in `_profileFromRow`. In `_ForumImage`, render the default asset when `imageUrl.trim().isEmpty` and use the same asset from `errorBuilder` for failed network requests.

- [ ] **Step 4: Run focused tests and the full Forum suite**

Run: `cd frontend && flutter test test/features/forum`

Expected: PASS with zero failures.

- [ ] **Step 5: Run static analysis for changed production files**

Run: `cd frontend && flutter analyze lib/core/auth/current_user_avatar_change.dart lib/core/auth/auth_repository.dart lib/features/forum`

Expected: `No issues found!`

- [ ] **Step 6: Commit normalization and fallback**

```bash
git add frontend/lib/features/forum/data/forum_avatar_url.dart frontend/lib/features/forum/data/forum_repository.dart frontend/lib/features/forum/presentation/widgets/forum_widgets.dart frontend/test/features/forum/data/forum_avatar_url_test.dart frontend/test/features/forum/presentation/forum_share_post_widgets_test.dart
git commit -m "fix: normalize forum avatar rendering"
```

---

### Task 4: Final Verification

**Files:**
- Verify only; no production files are added in this task.

**Interfaces:**
- Consumes all behavior from Tasks 1–3.
- Produces fresh test and analysis evidence for handoff.

- [ ] **Step 1: Run all targeted tests together**

Run: `cd frontend && flutter test test/core/auth/current_user_avatar_change_test.dart test/features/forum`

Expected: PASS with zero failures.

- [ ] **Step 2: Run analysis**

Run: `cd frontend && flutter analyze lib/core/auth/current_user_avatar_change.dart lib/core/auth/auth_repository.dart lib/features/forum`

Expected: `No issues found!`

- [ ] **Step 3: Verify the worktree scope**

Run: `git status --short && git diff --check`

Expected: no whitespace errors; pre-existing unrelated changes remain untouched.
