import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/forum/data/forum_page_cursor.dart';
import 'package:hellovietnam/features/forum/data/forum_repository.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/thread_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('opening a thread loads and renders its first comment page', (
    WidgetTester tester,
  ) async {
    final _ThreadForumRepository repository = _ThreadForumRepository(
      commentResponses: <Object>[
        ForumCommentsPage(
          comments: <ForumComment>[_comment('comment-1')],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    final ForumStore store = ForumStore.test(repository: repository);
    addTearDown(() => _disposeTestState(tester, store, repository));

    await tester.pumpWidget(_threadApp(store));
    await tester.pumpAndSettle();

    expect(repository.commentLoadCalls, 1);
    expect(repository.requestedCommentCursors, <ForumPageCursor?>[null]);
    expect(find.text('Comment comment-1'), findsOneWidget);
  });

  testWidgets('a failed initial comment page can be retried', (
    WidgetTester tester,
  ) async {
    final _ThreadForumRepository repository = _ThreadForumRepository(
      commentResponses: <Object>[
        StateError('temporary failure'),
        ForumCommentsPage(
          comments: <ForumComment>[_comment('comment-after-retry')],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    final ForumStore store = ForumStore.test(repository: repository);
    addTearDown(() => _disposeTestState(tester, store, repository));

    await tester.pumpWidget(_threadApp(store));
    await tester.pumpAndSettle();

    expect(find.text('Could not load comments.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.commentLoadCalls, 2);
    expect(find.text('Comment comment-after-retry'), findsOneWidget);
    expect(find.text('Could not load comments.'), findsNothing);
  });

  testWidgets('scrolling near the end loads the next comment page once', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ForumPageCursor nextCursor = ForumPageCursor(
      createdAt: DateTime.utc(2026, 7, 25),
      id: 'comment-20',
    );
    final _ThreadForumRepository repository = _ThreadForumRepository(
      commentResponses: <Object>[
        ForumCommentsPage(
          comments: List<ForumComment>.generate(
            20,
            (int index) => _comment('comment-${index + 1}'),
          ),
          nextCursor: nextCursor,
          hasMore: true,
        ),
        ForumCommentsPage(
          comments: <ForumComment>[_comment('comment-21')],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    final ForumStore store = ForumStore.test(repository: repository);
    addTearDown(() => _disposeTestState(tester, store, repository));

    await tester.pumpWidget(_threadApp(store));
    await tester.pumpAndSettle();

    expect(repository.commentLoadCalls, 1);

    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
      5000,
    );
    await tester.pumpAndSettle();

    expect(repository.commentLoadCalls, 2);
    expect(repository.requestedCommentCursors, <ForumPageCursor?>[
      null,
      nextCursor,
    ]);
    expect(find.text('Comment comment-21'), findsOneWidget);
  });
}

Widget _threadApp(ForumStore store) {
  return MaterialApp(
    theme: buildTheme(),
    darkTheme: buildDarkTheme(),
    home: ThreadPage(postId: 'post-1', store: store),
  );
}

Future<void> _disposeTestState(
  WidgetTester tester,
  ForumStore store,
  _ThreadForumRepository repository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  store.dispose();
  await repository.dispose();
}

class _ThreadForumRepository extends ForumRepository {
  _ThreadForumRepository({required this.commentResponses})
    : super(
        client: SupabaseClient(
          'https://example.supabase.co',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final List<Object> commentResponses;
  final List<ForumPageCursor?> requestedCommentCursors = <ForumPageCursor?>[];
  int commentLoadCalls = 0;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<ForumRepositorySnapshot> loadSnapshot({
    ForumPageCursor? beforeForYouCursor,
    ForumPageCursor? beforeFollowingCursor,
    int limit = 20,
    bool loadForYouPage = true,
    bool loadFollowingPage = true,
    bool includeNotifications = true,
  }) async {
    final ForumPost post = _post();
    return ForumRepositorySnapshot(
      currentUserId: 'user-1',
      currentUserProfile: _profile('user-1', isCurrentUser: true),
      profilesById: <String, ForumUserProfile>{
        'user-1': _profile('user-1', isCurrentUser: true),
        'user-2': _profile('user-2', isCurrentUser: false),
      },
      posts: <ForumPost>[post],
      commentsByPostId: const <String, List<ForumComment>>{},
      forYouFeedIds: const <String>['post-1'],
      followingFeedIds: const <String>[],
      notifications: const <ForumNotificationItem>[],
      blockedAuthorIds: const <String>{},
      reportedPostIds: const <String>{},
    );
  }

  @override
  Future<ForumCommentsPage> loadCommentsPage({
    required String postId,
    ForumPageCursor? beforeCursor,
    int limit = 20,
  }) async {
    requestedCommentCursors.add(beforeCursor);
    final int responseIndex = commentLoadCalls;
    commentLoadCalls += 1;
    final Object response = commentResponses[responseIndex];
    if (response is Error) {
      throw response;
    }
    if (response is Exception) {
      throw response;
    }
    return response as ForumCommentsPage;
  }

  Future<void> dispose() => _authStateController.close();
}

ForumPost _post() {
  return ForumPost(
    id: 'post-1',
    author: _profile('user-2', isCurrentUser: false).author,
    content: 'Thread post',
    imageUrls: const <String>[],
    timeAgo: 'now',
    likes: 0,
    comments: 21,
  );
}

ForumComment _comment(String id) {
  return ForumComment(
    id: id,
    author: _profile('user-2', isCurrentUser: false).author,
    content: 'Comment $id',
    timeAgo: 'now',
    likes: 0,
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
