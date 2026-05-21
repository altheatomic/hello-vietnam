import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ForumProfilePage extends StatelessWidget {
  const ForumProfilePage({super.key, required this.authorId});

  final String authorId;

  @override
  Widget build(BuildContext context) {
    final ForumStore store = ForumStore.instance;

    void showComingSoon(String message) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    void openProfile(String targetAuthorId) {
      if (store.isCurrentUser(targetAuthorId)) {
        context.push(AppRoutes.forumMe);
        return;
      }
      context.push(AppRoutes.forumProfilePath(targetAuthorId));
    }

    Future<void> openPostMenu(ForumPost post) async {
      final ForumPostMoreAction? action = await ForumPostMoreMenu.show(
        context,
        author: post.author,
        isFollowing: post.author.isFollowing,
      );
      if (!context.mounted || action == null) {
        return;
      }

      switch (action) {
        case ForumPostMoreAction.follow:
          store.toggleFollowAuthor(post.author.id);
          break;
        case ForumPostMoreAction.block:
          store.toggleBlockAuthor(post.author.id);
          showComingSoon('${post.author.name} đã bị block khỏi forum feed.');
          break;
        case ForumPostMoreAction.report:
          context.push(AppRoutes.forumReportPath(post.id));
          break;
      }
    }

    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListenableBuilder(
          listenable: store,
          builder: (BuildContext context, Widget? child) {
            final String targetAuthorId = authorId == 'me'
                ? store.currentUserId
                : authorId;
            final ForumUserProfile? profile = targetAuthorId.isEmpty
                ? null
                : store.profileById(targetAuthorId);
            if (profile == null) {
              if (store.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text(store.errorMessage ?? 'Profile not found'),
                ),
              );
            }

            final List<ForumPost> posts = store.postsByAuthor(targetAuthorId);

            return Column(
              children: <Widget>[
                ForumProfileTopBar(
                  title: profile.author.name,
                  subtitle: '${posts.length} posts',
                  onBack: () => context.pop(),
                  onBookmark: () => context.push(AppRoutes.forumSaved),
                  onNotification: () =>
                      context.push(AppRoutes.forumNotifications),
                  onAvatarTap: () => context.push(AppRoutes.forumMe),
                  avatarUrl: store.currentUserAuthor.avatarUrl,
                  showCurrentAvatar: profile.isCurrentUser,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      22,
                      AppConstants.pagePadding,
                      28,
                    ),
                    children: <Widget>[
                      ForumProfileHeaderCard(
                        profile: profile,
                        postsCount: posts.length,
                        onToggleFollow: () =>
                            store.toggleFollowAuthor(profile.author.id),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Posts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ForumColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...posts.map(
                        (ForumPost post) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: ForumPostCard(
                            post: post,
                            onOpen: () =>
                                context.push(AppRoutes.forumPostPath(post.id)),
                            onAuthorTap: () => openProfile(post.author.id),
                            onLike: () => store.toggleLike(post.id),
                            onComment: () =>
                                context.push(AppRoutes.forumPostPath(post.id)),
                            onBookmark: () => store.toggleBookmark(post.id),
                            onShare: () =>
                                showComingSoon('Share action sẽ được nối sau.'),
                            onFollow: () =>
                                store.toggleFollowAuthor(post.author.id),
                            onMore: () => openPostMenu(post),
                            showMoreButton: !store.isCurrentUser(
                              post.author.id,
                            ),
                            showInlineFollow: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
