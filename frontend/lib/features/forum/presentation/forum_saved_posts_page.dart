import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/forum_post_actions.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ForumSavedPostsPage extends StatelessWidget {
  const ForumSavedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ForumStore store = ForumStore.instance;

    void showMessage(String message) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    void openProfile(String authorId) {
      if (store.isCurrentUser(authorId)) {
        context.push(AppRoutes.forumMe);
        return;
      }

      context.push(AppRoutes.forumProfilePath(authorId));
    }

    void openSharedItem(SharedExploreItem item) {
      context.push(
        AppRoutes.detailPathForCategory(item.category),
        extra: item.toItemDetailRequest(),
      );
    }

    Future<void> openPostMenu(ForumPost post) async {
      await ForumPostActions.open(context, store: store, post: post);
    }

    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: <Widget>[
            ForumTopBar(
              title: context.l10n.ui('Saved Posts'),
              onBack: () => context.pop(),
              onBookmark: () {},
              onAvatarTap: () => context.push(AppRoutes.forumMe),
              avatarUrl: store.currentUserAuthor.avatarUrl,
              showBookmark: false,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: store,
                builder: (BuildContext context, Widget? child) {
                  final List<ForumPost> posts = store.savedPosts;
                  if (posts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.bookmark_border_rounded,
                              size: 36,
                              color: ForumColors.muted(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.ui('No saved posts yet'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ForumColors.foreground(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      22,
                      AppConstants.pagePadding,
                      28,
                    ),
                    itemCount: posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 18),
                    itemBuilder: (BuildContext context, int index) {
                      final ForumPost post = posts[index];
                      return ForumPostCard(
                        post: post,
                        onOpen: () =>
                            context.push(AppRoutes.forumPostPath(post.id)),
                        onAuthorTap: () => openProfile(post.author.id),
                        onLike: () => store.toggleLike(post.id),
                        onComment: () =>
                            context.push(AppRoutes.forumPostPath(post.id)),
                        onBookmark: () => store.toggleBookmark(post.id),
                        onShare: () =>
                            showMessage('Share action sẽ được nối sau.'),
                        onFollow: () =>
                            store.toggleFollowAuthor(post.author.id),
                        onMore: () => openPostMenu(post),
                        onSharedItemTap: post.sharedItem == null
                            ? null
                            : () => openSharedItem(post.sharedItem!),
                        showMoreButton: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
