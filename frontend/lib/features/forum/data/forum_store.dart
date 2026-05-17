import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/forum/data/forum_mock_data.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';

class ForumStore extends ChangeNotifier {
  ForumStore._()
    : _profilesById = Map<String, ForumUserProfile>.from(
        ForumMockData.profilesById,
      ),
      _postsById = <String, ForumPost>{
        for (final ForumPost post in ForumMockData.posts) post.id: post,
      },
      _commentsByPostId = <String, List<ForumComment>>{
        for (final MapEntry<String, List<ForumComment>> entry
            in ForumMockData.commentsByPost.entries)
          entry.key: List<ForumComment>.from(entry.value),
      },
      _forYouFeedIds = List<String>.from(ForumMockData.initialForYouFeed),
      _followingFeedIds = List<String>.from(ForumMockData.initialFollowingFeed);

  static final ForumStore instance = ForumStore._();

  final Map<String, ForumUserProfile> _profilesById;
  final Map<String, ForumPost> _postsById;
  final Map<String, List<ForumComment>> _commentsByPostId;
  final List<String> _forYouFeedIds;
  final List<String> _followingFeedIds;
  final Set<String> _blockedAuthorIds = <String>{};
  final Set<String> _reportedPostIds = <String>{};

  String get currentUserId => ForumMockData.currentUserId;

  ForumUserProfile get currentUserProfile => _profilesById[currentUserId]!;

  ForumAuthor get currentUserAuthor => currentUserProfile.author;

  List<ForumPost> get forYouPosts => _orderedPosts(_forYouFeedIds);

  List<ForumPost> get followingPosts => _orderedPosts(_followingFeedIds);

  List<ForumPost> get savedPosts {
    final Set<String> orderedIds = <String>{
      ..._forYouFeedIds,
      ..._followingFeedIds,
      ..._postsById.keys,
    };

    return orderedIds
        .map((String id) => _postsById[id])
        .whereType<ForumPost>()
        .where(
          (ForumPost post) =>
              post.isBookmarked && !_blockedAuthorIds.contains(post.author.id),
        )
        .toList(growable: false);
  }

  List<ForumNotificationItem> get notifications =>
      List<ForumNotificationItem>.unmodifiable(
        ForumMockData.notifications.where(
          (ForumNotificationItem item) =>
              !_blockedAuthorIds.contains(item.actor.id),
        ),
      );

  ForumPost? postById(String postId) {
    final ForumPost? post = _postsById[postId];
    if (post == null || _blockedAuthorIds.contains(post.author.id)) {
      return null;
    }
    return post;
  }

  ForumUserProfile? profileById(String authorId) => _profilesById[authorId];

  bool isCurrentUser(String authorId) => authorId == currentUserId;

  bool isAuthorBlocked(String authorId) => _blockedAuthorIds.contains(authorId);

  bool isPostReported(String postId) => _reportedPostIds.contains(postId);

  List<ForumPost> postsByAuthor(String authorId) {
    if (_blockedAuthorIds.contains(authorId)) {
      return const <ForumPost>[];
    }

    final Set<String> orderedIds = <String>{
      ..._forYouFeedIds,
      ..._followingFeedIds,
      ..._postsById.keys,
    };

    return orderedIds
        .map((String id) => _postsById[id])
        .whereType<ForumPost>()
        .where((ForumPost post) => post.author.id == authorId)
        .toList(growable: false);
  }

  int postsCountForAuthor(String authorId) => postsByAuthor(authorId).length;

  List<ForumComment> commentsForPost(String postId) {
    return List<ForumComment>.unmodifiable(
      _commentsByPostId[postId] ?? const <ForumComment>[],
    );
  }

  void toggleLike(String postId) {
    final ForumPost? post = _postsById[postId];
    if (post == null) {
      return;
    }

    _postsById[postId] = post.copyWith(
      isLiked: !post.isLiked,
      likes: post.isLiked ? post.likes - 1 : post.likes + 1,
    );
    notifyListeners();
  }

  void toggleBookmark(String postId) {
    final ForumPost? post = _postsById[postId];
    if (post == null) {
      return;
    }

    _postsById[postId] = post.copyWith(isBookmarked: !post.isBookmarked);
    notifyListeners();
  }

  void toggleFollowAuthor(String authorId) {
    final ForumUserProfile? profile = _profilesById[authorId];
    if (profile == null ||
        profile.isCurrentUser ||
        _blockedAuthorIds.contains(authorId)) {
      return;
    }

    final bool isFollowing = profile.author.isFollowing;
    final ForumUserProfile updatedTarget = profile.copyWith(
      author: profile.author.copyWith(isFollowing: !isFollowing),
      followersCount: isFollowing
          ? profile.followersCount - 1
          : profile.followersCount + 1,
    );
    _profilesById[authorId] = updatedTarget;

    final ForumUserProfile currentProfile = currentUserProfile;
    _profilesById[currentUserId] = currentProfile.copyWith(
      followingCount: isFollowing
          ? currentProfile.followingCount - 1
          : currentProfile.followingCount + 1,
    );

    _syncAuthorAcrossPosts(updatedTarget.author);
    _syncFollowingFeed(authorId: authorId, isFollowing: !isFollowing);
    notifyListeners();
  }

  void toggleBlockAuthor(String authorId) {
    final ForumUserProfile? profile = _profilesById[authorId];
    if (profile == null || profile.isCurrentUser) {
      return;
    }

    if (_blockedAuthorIds.remove(authorId)) {
      notifyListeners();
      return;
    }

    _blockedAuthorIds.add(authorId);

    if (profile.author.isFollowing) {
      final ForumUserProfile updatedTarget = profile.copyWith(
        author: profile.author.copyWith(isFollowing: false),
        followersCount: profile.followersCount - 1,
      );
      _profilesById[authorId] = updatedTarget;

      final ForumUserProfile currentProfile = currentUserProfile;
      _profilesById[currentUserId] = currentProfile.copyWith(
        followingCount: currentProfile.followingCount - 1,
      );

      _syncAuthorAcrossPosts(updatedTarget.author);
      _syncFollowingFeed(authorId: authorId, isFollowing: false);
    }

    notifyListeners();
  }

  void submitReport({
    required String postId,
    required String reason,
    String? details,
  }) {
    if (!_postsById.containsKey(postId)) {
      return;
    }

    _reportedPostIds.add(postId);
    notifyListeners();
  }

  void toggleCommentLike(String postId, String commentId) {
    final List<ForumComment> comments =
        _commentsByPostId[postId] ?? <ForumComment>[];
    final int index = comments.indexWhere(
      (ForumComment item) => item.id == commentId,
    );
    if (index < 0) {
      return;
    }

    final ForumComment comment = comments[index];
    comments[index] = comment.copyWith(
      isLiked: !comment.isLiked,
      likes: comment.isLiked ? comment.likes - 1 : comment.likes + 1,
    );
    notifyListeners();
  }

  void addReply({
    required String postId,
    required String replyText,
    String? replyToHandle,
  }) {
    final ForumPost? post = _postsById[postId];
    if (post == null) {
      return;
    }

    final String trimmed = replyText.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final String prefix = replyToHandle == null ? '' : '$replyToHandle ';
    final ForumComment reply = ForumComment(
      id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
      author: currentUserAuthor,
      content: '$prefix$trimmed'.trim(),
      timeAgo: 'now',
      likes: 0,
    );

    final List<ForumComment> comments = _commentsByPostId.putIfAbsent(
      postId,
      () => <ForumComment>[],
    );
    comments.insert(0, reply);
    _postsById[postId] = post.copyWith(comments: post.comments + 1);
    notifyListeners();
  }

  String createPost({
    required String content,
    required List<String> imageUrls,
  }) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Post content cannot be empty');
    }

    final String postId = 'post-${DateTime.now().microsecondsSinceEpoch}';
    final ForumPost post = ForumPost(
      id: postId,
      author: currentUserAuthor,
      content: trimmed,
      imageUrls: List<String>.from(imageUrls),
      timeAgo: 'now',
      likes: 0,
      comments: 0,
    );

    _postsById[postId] = post;
    _forYouFeedIds.insert(0, postId);
    notifyListeners();
    return postId;
  }

  List<ForumPost> _orderedPosts(List<String> ids) {
    return ids
        .map((String id) => _postsById[id])
        .whereType<ForumPost>()
        .where((ForumPost post) => !_blockedAuthorIds.contains(post.author.id))
        .toList(growable: false);
  }

  void _syncAuthorAcrossPosts(ForumAuthor updatedAuthor) {
    _postsById.updateAll((String key, ForumPost post) {
      if (post.author.id != updatedAuthor.id) {
        return post;
      }
      return post.copyWith(author: updatedAuthor);
    });

    _commentsByPostId.updateAll((String key, List<ForumComment> comments) {
      return comments
          .map((ForumComment comment) {
            if (comment.author.id != updatedAuthor.id) {
              return comment;
            }
            return comment.copyWith(author: updatedAuthor);
          })
          .toList(growable: false);
    });
  }

  void _syncFollowingFeed({
    required String authorId,
    required bool isFollowing,
  }) {
    final List<String> authorPostIds = _forYouFeedIds
        .where((String postId) => _postsById[postId]?.author.id == authorId)
        .toList(growable: false);

    if (isFollowing) {
      for (final String postId in authorPostIds.reversed) {
        if (!_followingFeedIds.contains(postId)) {
          _followingFeedIds.insert(0, postId);
        }
      }
      return;
    }

    _followingFeedIds.removeWhere(
      (String postId) => _postsById[postId]?.author.id == authorId,
    );
  }
}
