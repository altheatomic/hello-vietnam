import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
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
    Future<void>.microtask(() => _store.refresh());
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

  Future<void> _openPostMenu(ForumPost post) async {
    final ForumPostMoreAction? action = await ForumPostMoreMenu.show(
      context,
      author: post.author,
      isFollowing: post.author.isFollowing,
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ForumPostMoreAction.follow:
        _store.toggleFollowAuthor(post.author.id);
        break;
      case ForumPostMoreAction.block:
        _store.toggleBlockAuthor(post.author.id);
        _showComingSoon('${post.author.name} đã bị block khỏi forum feed.');
        break;
      case ForumPostMoreAction.report:
        context.push(AppRoutes.forumReportPath(post.id));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Post',
                      style: TextStyle(
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
              title: 'Forum',
              onBack: _handleBack,
              onBookmark: () => context.push(AppRoutes.forumSaved),
              onNotification: () => context.push(AppRoutes.forumNotifications),
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
                        currentUserId: _store.currentUserId,
                      ),
                      _ForumFeedList(
                        posts: _store.followingPosts,
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
                        currentUserId: _store.currentUserId,
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
    required this.currentUserId,
  });

  final List<ForumPost> posts;
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
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        18,
        AppConstants.pagePadding,
        104,
      ),
      itemCount: posts.length + (showComposer ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (BuildContext context, int index) {
        if (showComposer && index == 0) {
          return composer;
        }

        final int postIndex = showComposer ? index - 1 : index;
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
          showMoreButton: post.author.id != currentUserId,
        );
      },
    );
  }
}
