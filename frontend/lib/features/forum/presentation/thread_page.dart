import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/app_loading_screen.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/forum_post_actions.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.postId, this.store});

  final String postId;
  final ForumStore? store;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  late final ForumStore _store = widget.store ?? ForumStore.instance;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadThread());
  }

  @override
  void didUpdateWidget(covariant ThreadPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      unawaited(_loadThread());
    }
  }

  Future<void> _loadThread() async {
    await _store.ensureLoaded();
    if (!mounted || _store.postById(widget.postId) == null) {
      return;
    }
    await _store.ensureCommentsLoaded(widget.postId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 320) {
      unawaited(_store.loadMoreComments(widget.postId));
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ForumStore store = _store;
    final String postId = widget.postId;

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

    void openSharedItem(SharedExploreItem item) {
      context.push(
        AppRoutes.detailPathForCategory(item.category),
        extra: item.toItemDetailRequest(),
      );
    }

    void openSharedTripPlan(SharedTripPlanItem item) {
      context.push(AppRoutes.tripPlannerResultPath(idPlan: item.planId));
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
      final bool deleted = await ForumPostActions.open(
        context,
        store: store,
        post: post,
      );
      if (deleted && context.mounted) {
        context.pop();
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
                return AppLoadingScreen(
                  message: context.l10n.ui('Loading post'),
                  compact: true,
                );
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.forum_outlined,
                        size: 36,
                        color: ForumColors.muted(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        store.errorMessage ?? context.l10n.ui('Post not found'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ForumColors.foreground(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: Text(context.l10n.ui('Go back')),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: <Widget>[
                ForumTopBar(
                  title: context.l10n.ui('Post'),
                  onBack: () => context.pop(),
                  onBookmark: () => context.push(AppRoutes.forumSaved),
                  onAvatarTap: () => context.push(AppRoutes.forumMe),
                  avatarUrl: store.currentUserAuthor.avatarUrl,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
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
                          onSharedItemTap: post.sharedItem == null
                              ? null
                              : () => openSharedItem(post.sharedItem!),
                          onSharedTripPlanTap: post.sharedTripPlan == null
                              ? null
                              : () => openSharedTripPlan(post.sharedTripPlan!),
                          showMoreButton: true,
                          showInlineFollow: false,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.ui('Popular answers'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ForumColors.foreground(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (store.isLoadingComments(postId))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          )
                        else if (!store.hasLoadedComments(postId) &&
                            store.commentErrorForPost(postId) != null)
                          _CommentLoadError(
                            message: context.l10n.ui(
                              'Could not load comments.',
                            ),
                            onRetry: () => store.ensureCommentsLoaded(
                              postId,
                              forceRefresh: true,
                            ),
                          )
                        else if (comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                context.l10n.ui('No comments yet.'),
                                style: TextStyle(
                                  color: ForumColors.muted(context),
                                ),
                              ),
                            ),
                          )
                        else
                          ...comments.map(
                            (ForumComment comment) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: ForumCommentCard(
                                comment: comment,
                                onAuthorTap: () =>
                                    openProfile(comment.author.id),
                                onLike: () =>
                                    store.toggleCommentLike(postId, comment.id),
                                onReply: () => openReplyModal(
                                  post: post,
                                  replyToHandle: comment.author.handle,
                                ),
                              ),
                            ),
                          ),
                        if (store.isLoadingMoreComments(postId))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          )
                        else if (store.hasLoadedComments(postId) &&
                            store.commentErrorForPost(postId) != null)
                          _CommentLoadError(
                            message: context.l10n.ui(
                              'Could not load more comments.',
                            ),
                            onRetry: () => store.loadMoreComments(postId),
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

class _CommentLoadError extends StatelessWidget {
  const _CommentLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: ForumColors.muted(context)),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.ui('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
