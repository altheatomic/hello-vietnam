import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/data/forum_repository.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('init can skip the initial forum snapshot preload', () async {
    final _FakeForumRepository repository = _FakeForumRepository();
    final ForumStore store = ForumStore.test(repository: repository);

    await store.init(preload: false);

    expect(repository.loadSnapshotCalls, 0);

    await store.ensureLoaded();

    expect(repository.loadSnapshotCalls, 1);
    await repository.dispose();
  });
}

class _FakeForumRepository extends ForumRepository {
  _FakeForumRepository()
    : super(client: SupabaseClient('https://example.supabase.co', 'anon-key'));

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  int loadSnapshotCalls = 0;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<ForumRepositorySnapshot> loadSnapshot() async {
    loadSnapshotCalls += 1;
    return ForumRepositorySnapshot(
      currentUserId: 'user-1',
      currentUserProfile: _profile('user-1', isCurrentUser: true),
      profilesById: <String, ForumUserProfile>{
        'user-1': _profile('user-1', isCurrentUser: true),
      },
      posts: const <ForumPost>[],
      commentsByPostId: const <String, List<ForumComment>>{},
      forYouFeedIds: const <String>[],
      followingFeedIds: const <String>[],
      notifications: const <ForumNotificationItem>[],
      blockedAuthorIds: const <String>{},
      reportedPostIds: const <String>{},
    );
  }

  Future<void> dispose() => _authStateController.close();
}

ForumUserProfile _profile(String id, {required bool isCurrentUser}) {
  return ForumUserProfile(
    author: ForumAuthor(
      id: id,
      name: isCurrentUser ? 'You' : 'Forum user',
      handle: '@$id',
      avatarUrl: '',
    ),
    followersCount: 0,
    followingCount: 0,
    isCurrentUser: isCurrentUser,
  );
}
