import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ThreadPage extends StatelessWidget {
  const ThreadPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final ForumStore store = ForumStore.instance;

    void showComingSoon(String message) {
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

    void openReplyModal({
      required ForumPost post,
      required String replyToHandle,
    }) {
      ForumReplyDialog.show(
        context,
        post: post,
        replyingToHandle: replyToHandle,
        currentUser: store.currentUserAuthor,
        onSubmit: (String text) {
          store.addReply(
            postId: post.id,
            replyText: text,
            replyToHandle: replyToHandle,
          );
        },
      );
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
            final ForumPost? post = store.postById(postId);
            final List<ForumComment> comments = store.commentsForPost(postId);

            if (post == null) {
              if (store.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.forum_outlined,
                        size: 36,
                        color: ForumColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        store.errorMessage ?? 'Post not found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ForumColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Go back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: <Widget>[
                ForumTopBar(
                  title: 'Post',
                  onBack: () => context.pop(),
                  onBookmark: () => context.push(AppRoutes.forumSaved),
                  onNotification: () =>
                      context.push(AppRoutes.forumNotifications),
                  onAvatarTap: () => context.push(AppRoutes.forumMe),
                  avatarUrl: store.currentUserAuthor.avatarUrl,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      22,
                      AppConstants.pagePadding,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ForumPostCard(
                          post: post,
                          onOpen: () {},
                          onAuthorTap: () => openProfile(post.author.id),
                          onLike: () => store.toggleLike(postId),
                          onComment: () => openReplyModal(
                            post: post,
                            replyToHandle: post.author.handle,
                          ),
                          onBookmark: () => store.toggleBookmark(postId),
                          onShare: () =>
                              showComingSoon('Share action sẽ được nối sau.'),
                          onFollow: () =>
                              store.toggleFollowAuthor(post.author.id),
                          onMore: () => openPostMenu(post),
                          showMoreButton: !store.isCurrentUser(post.author.id),
                          showInlineFollow: false,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Popular answers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ForumColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...comments.map(
                          (ForumComment comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: ForumCommentCard(
                              comment: comment,
                              onAuthorTap: () => openProfile(comment.author.id),
                              onLike: () =>
                                  store.toggleCommentLike(postId, comment.id),
                              onReply: () => openReplyModal(
                                post: post,
                                replyToHandle: comment.author.handle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
