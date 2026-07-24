import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  const ForumAuthor author = ForumAuthor(
    id: 'author-1',
    name: 'Thái Cao Phạm Hoàng',
    handle: '@caothai0711',
    avatarUrl: '',
  );

  const ForumPost post = ForumPost(
    id: 'post-1',
    author: author,
    content: 'hello',
    imageUrls: <String>[],
    timeAgo: '5m',
    likes: 0,
    comments: 1,
  );

  testWidgets('reply dialog stays usable above a compact phone keyboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() async {
      tester.view.resetViewInsets();
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => ForumReplyDialog.show(
                  context,
                  post: post,
                  replyingToHandle: author.handle,
                  currentUser: author,
                  onSubmit: (_) {},
                ),
                child: const Text('Open reply'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A compact reply');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.enabledBorder, InputBorder.none);
    expect(field.decoration?.focusedBorder, InputBorder.none);
  });

  testWidgets('profile header fits a narrow phone without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ForumProfileTopBar(
                  title: author.name,
                  subtitle: '2 bài viết',
                  onBack: () {},
                  onBookmark: () {},
                  onAvatarTap: () {},
                  avatarUrl: author.avatarUrl,
                  showCurrentAvatar: true,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ForumProfileHeaderCard(
                    profile: const ForumUserProfile(
                      author: author,
                      followersCount: 0,
                      followingCount: 3,
                      isCurrentUser: true,
                    ),
                    postsCount: 2,
                    onToggleFollow: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shared cards use readable dark-mode foreground colors', (
    WidgetTester tester,
  ) async {
    const SharedExploreItem item = SharedExploreItem(
      contentType: 'activity',
      contentId: 'activity-1',
      provinceId: 'province-1',
      title: 'Cycling around Con Dao',
      imagePath: '',
      category: DetailCategory.activities,
      provinceName: 'Ba Ria - Vung Tau',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: ForumSharedItemCard(item: item)),
      ),
    );

    final Text title = tester.widget<Text>(find.text('Cycling around Con Dao'));
    expect(title.style?.color, ForumColors.darkText);
  });
}
