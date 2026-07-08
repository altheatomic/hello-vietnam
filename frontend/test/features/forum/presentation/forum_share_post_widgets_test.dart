import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/features/explore/data/explore_tracking_service.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/create_post_page.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
      return;
    } catch (_) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    }
  });

  const SharedExploreItem sharedItem = SharedExploreItem(
    contentType: 'activity',
    contentId: 'activity-1',
    provinceId: 'province-1',
    title: 'Ba Na Hills Cable Car',
    imagePath: '',
    category: DetailCategory.activities,
    provinceName: 'Da Nang',
  );

  testWidgets('share composer hides add photo controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          request: const CreateForumPostRequest(sharedExploreItem: sharedItem),
          currentUserAuthor: const ForumAuthor(
            id: 'user-1',
            name: 'Phuc',
            handle: '@phuc',
            avatarUrl: '',
          ),
          createPost: ({
            required String content,
            List<String> imageUrls = const <String>[],
            List<XFile> imageFiles = const <XFile>[],
            SharedExploreItem? sharedExploreItem,
          }) async {
            return 'post-1';
          },
        ),
      ),
    );

    expect(find.text('Add photos'), findsNothing);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    expect(find.text('Ba Na Hills Cable Car'), findsOneWidget);
  });

  testWidgets('share composer can post shared item without extra text', (
    WidgetTester tester,
  ) async {
    final List<String> createdContents = <String>[];
    final List<Map<String, dynamic>> trackedBodies = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          request: const CreateForumPostRequest(sharedExploreItem: sharedItem),
          currentUserAuthor: const ForumAuthor(
            id: 'user-1',
            name: 'Phuc',
            handle: '@phuc',
            avatarUrl: '',
          ),
          createPost: ({
            required String content,
            List<String> imageUrls = const <String>[],
            List<XFile> imageFiles = const <XFile>[],
            SharedExploreItem? sharedExploreItem,
          }) async {
            createdContents.add(content);
            expect(sharedExploreItem, isNotNull);
            return 'post-1';
          },
          exploreTrackingService: ExploreTrackingService(
            sender: ({
              Map<String, String>? headers,
              required Map<String, dynamic> body,
            }) async {
              trackedBodies.add(body);
            },
            accessTokenProvider: () => 'test-token',
            requestIdGenerator: () => 'request-1',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(createdContents, <String>['']);
    expect(trackedBodies, hasLength(1));
    expect(trackedBodies.single['eventType'], 'share');
    expect(trackedBodies.single['contentId'], 'activity-1');
  });

  testWidgets('forum post card renders shared item and handles tap', (
    WidgetTester tester,
  ) async {
    bool wasTapped = false;
    final ForumPost post = ForumPost(
      id: 'post-1',
      author: const ForumAuthor(
        id: 'user-1',
        name: 'Phuc',
        handle: '@phuc',
        avatarUrl: '',
      ),
      content: 'Worth checking out on your trip.',
      imageUrls: const <String>[],
      timeAgo: 'now',
      likes: 0,
      comments: 0,
      sharedItem: sharedItem,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForumPostCard(
            post: post,
            onOpen: () {},
            onAuthorTap: () {},
            onLike: () {},
            onComment: () {},
            onBookmark: () {},
            onShare: () {},
            onFollow: () {},
            onMore: () {},
            onSharedItemTap: () {
              wasTapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ba Na Hills Cable Car'));
    await tester.pump();

    expect(find.text('Da Nang'), findsOneWidget);
    expect(wasTapped, isTrue);
  });
}
