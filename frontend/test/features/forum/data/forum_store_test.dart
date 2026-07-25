import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/data/forum_repository.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:image_picker/image_picker.dart';
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

  test('loadMoreForYou appends the next cursor page', () async {
    final _FakeForumRepository repository = _FakeForumRepository(
      seededPages: <String?, ForumRepositorySnapshot>{
        null: _snapshot(
          posts: <ForumPost>[_post('post-1', authorId: 'user-2')],
          forYouFeedIds: const <String>['post-1'],
          nextForYouCursor: 'cursor-1',
          hasMoreForYou: true,
        ),
        'cursor-1': _snapshot(
          posts: <ForumPost>[_post('post-2', authorId: 'user-3')],
          forYouFeedIds: const <String>['post-2'],
          nextForYouCursor: null,
          hasMoreForYou: false,
        ),
      },
    );
    final ForumStore store = ForumStore.test(repository: repository);

    await store.ensureLoaded();
    await store.loadMoreForYou();

    expect(store.forYouPosts.map((ForumPost post) => post.id), <String>[
      'post-1',
      'post-2',
    ]);
    expect(repository.requestedForYouCursors, <String?>[null, 'cursor-1']);
    await repository.dispose();
  });

  test('toggleLike persists without reloading the feed snapshot', () async {
    final _FakeForumRepository repository = _FakeForumRepository(
      seededPages: <String?, ForumRepositorySnapshot>{
        null: _snapshot(
          posts: <ForumPost>[_post('post-1', authorId: 'user-2')],
          forYouFeedIds: const <String>['post-1'],
        ),
      },
    );
    final ForumStore store = ForumStore.test(repository: repository);

    await store.ensureLoaded();
    store.toggleLike('post-1');
    await Future<void>.delayed(Duration.zero);

    expect(repository.setPostLikedCalls, 1);
    expect(repository.loadSnapshotCalls, 1);
    expect(store.postById('post-1')?.isLiked, isTrue);
    expect(store.postById('post-1')?.likes, 1);
    await repository.dispose();
  });

  test('updatePost updates an owned post without reloading the feed', () async {
    final _FakeForumRepository repository = _FakeForumRepository(
      seededPages: <String?, ForumRepositorySnapshot>{
        null: _snapshot(
          posts: <ForumPost>[_post('post-1', authorId: 'user-1')],
          forYouFeedIds: const <String>['post-1'],
          followingFeedIds: const <String>['post-1'],
        ),
      },
    );
    final ForumStore store = ForumStore.test(repository: repository);

    await store.ensureLoaded();
    await store.updatePost(
      postId: 'post-1',
      content: 'Updated content',
      retainedImageUrls: const <String>[],
    );

    expect(repository.updatePostCalls, 1);
    expect(repository.loadSnapshotCalls, 1);
    expect(store.postById('post-1')?.content, 'Updated content');
    expect(store.postById('post-1')?.imageUrls, <String>['new-image.jpg']);
    await repository.dispose();
  });

  test('updatePost rejects posts owned by another user', () async {
    final _FakeForumRepository repository = _FakeForumRepository(
      seededPages: <String?, ForumRepositorySnapshot>{
        null: _snapshot(
          posts: <ForumPost>[_post('post-1', authorId: 'user-2')],
          forYouFeedIds: const <String>['post-1'],
        ),
      },
    );
    final ForumStore store = ForumStore.test(repository: repository);

    await store.ensureLoaded();

    expect(
      () => store.updatePost(
        postId: 'post-1',
        content: 'Not allowed',
        retainedImageUrls: const <String>[],
      ),
      throwsA(isA<StateError>()),
    );
    expect(repository.updatePostCalls, 0);
    await repository.dispose();
  });

  test('deletePost removes an owned post from every local view', () async {
    final _FakeForumRepository repository = _FakeForumRepository(
      seededPages: <String?, ForumRepositorySnapshot>{
        null: _snapshot(
          posts: <ForumPost>[
            _post('post-1', authorId: 'user-1', isBookmarked: true),
          ],
          forYouFeedIds: const <String>['post-1'],
          followingFeedIds: const <String>['post-1'],
        ),
      },
    );
    final ForumStore store = ForumStore.test(repository: repository);

    await store.ensureLoaded();
    await store.deletePost('post-1');

    expect(repository.deletePostCalls, 1);
    expect(store.postById('post-1'), isNull);
    expect(store.forYouPosts, isEmpty);
    expect(store.followingPosts, isEmpty);
    expect(store.savedPosts, isEmpty);
    await repository.dispose();
  });
}

class _FakeForumRepository extends ForumRepository {
  _FakeForumRepository({Map<String?, ForumRepositorySnapshot>? seededPages})
    : super(client: SupabaseClient('https://example.supabase.co', 'anon-key')) {
    pagesByCursor = <String?, ForumRepositorySnapshot>{
      null: _snapshot(),
      ...?seededPages,
    };
  }

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  late final Map<String?, ForumRepositorySnapshot> pagesByCursor;
  int loadSnapshotCalls = 0;
  int setPostLikedCalls = 0;
  int updatePostCalls = 0;
  int deletePostCalls = 0;
  final List<String?> requestedForYouCursors = <String?>[];

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<ForumRepositorySnapshot> loadSnapshot({
    String? beforeForYouCursor,
    String? beforeFollowingCursor,
    int limit = 20,
    bool loadForYouPage = true,
    bool loadFollowingPage = true,
    bool includeNotifications = true,
  }) async {
    loadSnapshotCalls += 1;
    requestedForYouCursors.add(beforeForYouCursor);
    return pagesByCursor[beforeForYouCursor] ?? _snapshot();
  }

  @override
  Future<void> setPostLiked({
    required String postId,
    required bool liked,
  }) async {
    setPostLikedCalls += 1;
  }

  @override
  Future<List<String>> updatePost({
    required String postId,
    required String content,
    required List<String> retainedImageUrls,
    List<XFile> imageFiles = const <XFile>[],
  }) async {
    updatePostCalls += 1;
    return const <String>['new-image.jpg'];
  }

  @override
  Future<void> deletePost(String postId) async {
    deletePostCalls += 1;
  }

  Future<void> dispose() => _authStateController.close();
}

ForumRepositorySnapshot _snapshot({
  List<ForumPost> posts = const <ForumPost>[],
  List<String> forYouFeedIds = const <String>[],
  List<String> followingFeedIds = const <String>[],
  String? nextForYouCursor,
  String? nextFollowingCursor,
  bool hasMoreForYou = false,
  bool hasMoreFollowing = false,
}) {
  final Map<String, ForumUserProfile> profilesById = <String, ForumUserProfile>{
    'user-1': _profile('user-1', isCurrentUser: true),
    for (final ForumPost post in posts)
      post.author.id: _profile(post.author.id, isCurrentUser: false),
  };
  return ForumRepositorySnapshot(
    currentUserId: 'user-1',
    currentUserProfile: profilesById['user-1']!,
    profilesById: profilesById,
    posts: posts,
    commentsByPostId: const <String, List<ForumComment>>{},
    forYouFeedIds: forYouFeedIds,
    followingFeedIds: followingFeedIds,
    notifications: const <ForumNotificationItem>[],
    blockedAuthorIds: const <String>{},
    reportedPostIds: const <String>{},
    nextForYouCursor: nextForYouCursor,
    nextFollowingCursor: nextFollowingCursor,
    hasMoreForYou: hasMoreForYou,
    hasMoreFollowing: hasMoreFollowing,
  );
}

ForumPost _post(
  String id, {
  required String authorId,
  bool isBookmarked = false,
}) {
  return ForumPost(
    id: id,
    author: _profile(authorId, isCurrentUser: false).author,
    content: 'Post $id',
    imageUrls: const <String>[],
    timeAgo: 'now',
    likes: 0,
    comments: 0,
    isBookmarked: isBookmarked,
    showFollowButton: true,
  );
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
