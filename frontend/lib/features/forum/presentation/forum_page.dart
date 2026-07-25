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

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ForumStore _store = ForumStore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future<void>.microtask(_store.ensureLoaded);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    context.go(AppRoutes.home);
  }

  Future<void> _openCreatePost() async {
    final String? createdPostId = await context.push<String?>(
      AppRoutes.forumCreate,
    );
    if (!mounted || createdPostId == null) {
      return;
    }

    context.push(AppRoutes.forumPostPath(createdPostId));
  }

  void _openProfile(String authorId) {
    if (_store.isCurrentUser(authorId)) {
      context.push(AppRoutes.forumMe);
      return;
    }

    context.push(AppRoutes.forumProfilePath(authorId));
  }

  void _openSharedItem(SharedExploreItem item) {
    context.push(
      AppRoutes.detailPathForCategory(item.category),
      extra: item.toItemDetailRequest(),
    );
  }

  void _openSharedTripPlan(SharedTripPlanItem item) {
    context.push(AppRoutes.tripPlannerResultPath(idPlan: item.planId));
  }

  Future<void> _openPostMenu(ForumPost post) async {
    await ForumPostActions.open(context, store: _store, post: post);
  }

  @override
  Widget build(BuildContext context) {
    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: const _ForumPostFabLocation(),
        floatingActionButton: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ForumColors.primaryGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ForumColors.cyanPrimary.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openCreatePost,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.ui('Post'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: <Widget>[
            ForumTopBar(
              title: context.l10n.forum,
              onBack: _handleBack,
              onBookmark: () => context.push(AppRoutes.forumSaved),
              onAvatarTap: () => context.push(AppRoutes.forumMe),
              avatarUrl: _store.currentUserAuthor.avatarUrl,
            ),
            ForumTabBar(tabController: _tabController),
            Expanded(
              child: ListenableBuilder(
                listenable: _store,
                builder: (BuildContext context, Widget? child) {
                  return TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _ForumFeedList(
                        posts: _store.forYouPosts,
                        onRefresh: () => _store.refresh(),
                        composer: ForumPostComposerPrompt(
                          avatarUrl: _store.currentUserAuthor.avatarUrl,
                          onTap: _openCreatePost,
                        ),
                        showComposer: true,
                        onOpen: (String postId) =>
                            context.push(AppRoutes.forumPostPath(postId)),
                        onAuthorTap: _openProfile,
                        onLike: _store.toggleLike,
                        onComment: (String postId) =>
                            context.push(AppRoutes.forumPostPath(postId)),
                        onBookmark: _store.toggleBookmark,
                        onShare: (String _) =>
                            _showComingSoon('Share action sẽ được nối sau.'),
                        onFollow: _store.toggleFollowAuthor,
                        onMore: _openPostMenu,
                        onSharedItemTap: _openSharedItem,
                        onSharedTripPlanTap: _openSharedTripPlan,
                        hasMore: _store.hasMoreForYou,
                        isLoadingMore: _store.isLoadingMoreForYou,
                        onLoadMore: _store.loadMoreForYou,
                      ),
                      _ForumFeedList(
                        posts: _store.followingPosts,
                        onRefresh: () => _store.refresh(),
                        composer: const SizedBox.shrink(),
                        showComposer: false,
                        onOpen: (String postId) =>
                            context.push(AppRoutes.forumPostPath(postId)),
                        onAuthorTap: _openProfile,
                        onLike: _store.toggleLike,
                        onComment: (String postId) =>
                            context.push(AppRoutes.forumPostPath(postId)),
                        onBookmark: _store.toggleBookmark,
                        onShare: (String _) =>
                            _showComingSoon('Share action sẽ được nối sau.'),
                        onFollow: _store.toggleFollowAuthor,
                        onMore: _openPostMenu,
                        onSharedItemTap: _openSharedItem,
                        onSharedTripPlanTap: _openSharedTripPlan,
                        hasMore: _store.hasMoreFollowing,
                        isLoadingMore: _store.isLoadingMoreFollowing,
                        onLoadMore: _store.loadMoreFollowing,
                      ),
                    ],
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

class _ForumFeedList extends StatelessWidget {
  const _ForumFeedList({
    required this.posts,
    required this.onRefresh,
    required this.composer,
    required this.showComposer,
    required this.onOpen,
    required this.onAuthorTap,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onShare,
    required this.onFollow,
    required this.onMore,
    required this.onSharedItemTap,
    required this.onSharedTripPlanTap,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<ForumPost> posts;
  final Future<void> Function() onRefresh;
  final Widget composer;
  final bool showComposer;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onAuthorTap;
  final ValueChanged<String> onLike;
  final ValueChanged<String> onComment;
  final ValueChanged<String> onBookmark;
  final ValueChanged<String> onShare;
  final ValueChanged<String> onFollow;
  final ValueChanged<ForumPost> onMore;
  final ValueChanged<SharedExploreItem> onSharedItemTap;
  final ValueChanged<SharedTripPlanItem> onSharedTripPlanTap;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final int composerCount = showComposer ? 1 : 0;
    final int loaderCount = hasMore || isLoadingMore ? 1 : 0;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.extentAfter < 640 &&
              hasMore &&
              !isLoadingMore) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            18,
            AppConstants.pagePadding,
            144,
          ),
          itemCount: posts.length + composerCount + loaderCount,
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (BuildContext context, int index) {
            if (showComposer && index == 0) {
              return composer;
            }

            final int postIndex = index - composerCount;
            if (postIndex >= posts.length) {
              return _ForumLoadMoreIndicator(isLoading: isLoadingMore);
            }

            final ForumPost post = posts[postIndex];
            return ForumPostCard(
              post: post,
              onOpen: () => onOpen(post.id),
              onAuthorTap: () => onAuthorTap(post.author.id),
              onLike: () => onLike(post.id),
              onComment: () => onComment(post.id),
              onBookmark: () => onBookmark(post.id),
              onShare: () => onShare(post.id),
              onFollow: () => onFollow(post.author.id),
              onMore: () => onMore(post),
              onSharedItemTap: post.sharedItem == null
                  ? null
                  : () => onSharedItemTap(post.sharedItem!),
              onSharedTripPlanTap: post.sharedTripPlan == null
                  ? null
                  : () => onSharedTripPlanTap(post.sharedTripPlan!),
              showMoreButton: true,
            );
          },
        ),
      ),
    );
  }
}

class _ForumLoadMoreIndicator extends StatelessWidget {
  const _ForumLoadMoreIndicator({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return const SizedBox(height: 56);
    }

    return const SizedBox(
      height: 64,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _ForumPostFabLocation extends FloatingActionButtonLocation {
  const _ForumPostFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        24;
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        116;
    return Offset(fabX, fabY);
  }
}
