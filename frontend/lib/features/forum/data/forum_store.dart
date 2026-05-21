import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/forum_models.dart';
import 'forum_repository.dart';

class ForumStore extends ChangeNotifier {
  ForumStore._({ForumRepository? repository})
    : _repository = repository ?? ForumRepository();

  static final ForumStore instance = ForumStore._();

  final ForumRepository _repository;

  final Map<String, ForumUserProfile> _profilesById =
      <String, ForumUserProfile>{};
  final Map<String, ForumPost> _postsById = <String, ForumPost>{};
  final Map<String, List<ForumComment>> _commentsByPostId =
      <String, List<ForumComment>>{};
  final List<String> _forYouFeedIds = <String>[];
  final List<String> _followingFeedIds = <String>[];
  final Set<String> _blockedAuthorIds = <String>{};
  final Set<String> _reportedPostIds = <String>{};
  List<ForumNotificationItem> _notifications = <ForumNotificationItem>[];
  StreamSubscription<AuthState>? _authSubscription;

  String _currentUserId = '';
  ForumUserProfile? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get currentUserId => _currentUserId;

  ForumUserProfile get currentUserProfile =>
      _currentUserProfile ??
      ForumUserProfile(
        author: const ForumAuthor(
          id: '',
          name: 'Forum user',
          handle: '@forum_user',
          avatarUrl: '',
        ),
        followersCount: 0,
        followingCount: 0,
        isCurrentUser: true,
      );

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
      List<ForumNotificationItem>.unmodifiable(_notifications);

  Future<void> init() async {
    _authSubscription ??= _repository.authStateChanges.listen((AuthState data) {
      if (data.session?.user == null) {
        _clear();
        notifyListeners();
        return;
      }

      unawaited(refresh());
    });

    await refresh();
  }

  Future<void> refresh({bool notifyLoading = true}) async {
    if (notifyLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final ForumRepositorySnapshot snapshot = await _repository.loadSnapshot();
      _applySnapshot(snapshot);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Load forum data error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
    if (post == null) return;

    final bool shouldLike = !post.isLiked;
    _postsById[postId] = post.copyWith(
      isLiked: shouldLike,
      likes: shouldLike ? post.likes + 1 : post.likes - 1,
    );
    notifyListeners();

    unawaited(
      _persistAndRefresh(
        () => _repository.setPostLiked(postId: postId, liked: shouldLike),
      ),
    );
  }

  void toggleBookmark(String postId) {
    final ForumPost? post = _postsById[postId];
    if (post == null) return;

    final bool shouldBookmark = !post.isBookmarked;
    _postsById[postId] = post.copyWith(isBookmarked: shouldBookmark);
    notifyListeners();

    unawaited(
      _persistAndRefresh(
        () => _repository.setBookmarked(
          postId: postId,
          bookmarked: shouldBookmark,
        ),
      ),
    );
  }

  void toggleFollowAuthor(String authorId) {
    final ForumUserProfile? profile = _profilesById[authorId];
    if (profile == null ||
        profile.isCurrentUser ||
        _blockedAuthorIds.contains(authorId)) {
      return;
    }

    final bool shouldFollow = !profile.author.isFollowing;
    _setAuthorFollowing(authorId: authorId, isFollowing: shouldFollow);
    _syncFollowingFeed(authorId: authorId, isFollowing: shouldFollow);
    notifyListeners();

    unawaited(
      _persistAndRefresh(
        () => _repository.setFollowing(
          authorId: authorId,
          following: shouldFollow,
        ),
      ),
    );
  }

  void toggleBlockAuthor(String authorId) {
    final ForumUserProfile? profile = _profilesById[authorId];
    if (profile == null || profile.isCurrentUser) return;

    final bool shouldBlock = !_blockedAuthorIds.contains(authorId);
    if (shouldBlock) {
      _blockedAuthorIds.add(authorId);
      _setAuthorFollowing(authorId: authorId, isFollowing: false);
      _syncFollowingFeed(authorId: authorId, isFollowing: false);
    } else {
      _blockedAuthorIds.remove(authorId);
    }
    notifyListeners();

    unawaited(
      _persistAndRefresh(
        () => _repository.setBlocked(authorId: authorId, blocked: shouldBlock),
      ),
    );
  }

  void submitReport({
    required String postId,
    required String reason,
    String? details,
  }) {
    if (!_postsById.containsKey(postId)) return;

    _reportedPostIds.add(postId);
    notifyListeners();

    unawaited(
      _persistAndRefresh(
        () => _repository.submitReport(
          postId: postId,
          reason: reason,
          details: details,
        ),
      ),
    );
  }

  void toggleCommentLike(String postId, String commentId) {
    final List<ForumComment> comments =
        _commentsByPostId[postId] ?? <ForumComment>[];
    final int index = comments.indexWhere(
      (ForumComment item) => item.id == commentId,
    );
    if (index < 0) return;

    final ForumComment comment = comments[index];
    final bool shouldLike = !comment.isLiked;
    comments[index] = comment.copyWith(
      isLiked: shouldLike,
      likes: shouldLike ? comment.likes + 1 : comment.likes - 1,
    );
    notifyListeners();

    unawaited(
      _persistAndRefresh(
        () => _repository.setCommentLiked(
          commentId: commentId,
          liked: shouldLike,
        ),
      ),
    );
  }

  void addReply({
    required String postId,
    required String replyText,
    String? replyToHandle,
  }) {
    final ForumPost? post = _postsById[postId];
    if (post == null) return;

    final String trimmed = replyText.trim();
    if (trimmed.isEmpty) return;

    final String prefix = replyToHandle == null ? '' : '$replyToHandle ';
    final String content = '$prefix$trimmed'.trim();
    final ForumComment reply = ForumComment(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      author: currentUserAuthor,
      content: content,
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

    unawaited(
      _persistAndRefresh(
        () => _repository.addReply(postId: postId, content: content),
      ),
    );
  }

  Future<String> createPost({
    required String content,
    List<String> imageUrls = const <String>[],
    List<XFile> imageFiles = const <XFile>[],
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Post content cannot be empty');
    }

    final String postId = await _repository.createPost(
      content: trimmed,
      imageUrls: imageUrls,
      imageFiles: imageFiles,
    );
    await refresh(notifyLoading: false);
    return postId;
  }

  List<ForumPost> _orderedPosts(List<String> ids) {
    return ids
        .map((String id) => _postsById[id])
        .whereType<ForumPost>()
        .where((ForumPost post) => !_blockedAuthorIds.contains(post.author.id))
        .toList(growable: false);
  }

  void _applySnapshot(ForumRepositorySnapshot snapshot) {
    _currentUserId = snapshot.currentUserId;
    _currentUserProfile = snapshot.currentUserProfile;
    _profilesById
      ..clear()
      ..addAll(snapshot.profilesById);
    _postsById
      ..clear()
      ..addEntries(
        snapshot.posts.map(
          (ForumPost post) => MapEntry<String, ForumPost>(post.id, post),
        ),
      );
    _commentsByPostId
      ..clear()
      ..addAll(
        snapshot.commentsByPostId.map(
          (String key, List<ForumComment> value) =>
              MapEntry<String, List<ForumComment>>(
                key,
                List<ForumComment>.from(value),
              ),
        ),
      );
    _forYouFeedIds
      ..clear()
      ..addAll(snapshot.forYouFeedIds);
    _followingFeedIds
      ..clear()
      ..addAll(snapshot.followingFeedIds);
    _blockedAuthorIds
      ..clear()
      ..addAll(snapshot.blockedAuthorIds);
    _reportedPostIds
      ..clear()
      ..addAll(snapshot.reportedPostIds);
    _notifications = List<ForumNotificationItem>.from(snapshot.notifications);
  }

  void _clear() {
    _currentUserId = '';
    _currentUserProfile = null;
    _profilesById.clear();
    _postsById.clear();
    _commentsByPostId.clear();
    _forYouFeedIds.clear();
    _followingFeedIds.clear();
    _blockedAuthorIds.clear();
    _reportedPostIds.clear();
    _notifications = <ForumNotificationItem>[];
    _errorMessage = null;
    _isLoading = false;
  }

  void _setAuthorFollowing({
    required String authorId,
    required bool isFollowing,
  }) {
    final ForumUserProfile? profile = _profilesById[authorId];
    if (profile == null) return;

    final bool wasFollowing = profile.author.isFollowing;
    if (wasFollowing == isFollowing) return;

    final ForumUserProfile updatedTarget = profile.copyWith(
      author: profile.author.copyWith(isFollowing: isFollowing),
      followersCount: isFollowing
          ? profile.followersCount + 1
          : profile.followersCount - 1,
    );
    _profilesById[authorId] = updatedTarget;

    final ForumUserProfile currentProfile = currentUserProfile;
    _currentUserProfile = currentProfile.copyWith(
      followingCount: isFollowing
          ? currentProfile.followingCount + 1
          : currentProfile.followingCount - 1,
    );
    if (_currentUserId.isNotEmpty) {
      _profilesById[_currentUserId] = _currentUserProfile!;
    }

    _syncAuthorAcrossPosts(updatedTarget.author);
  }

  void _syncAuthorAcrossPosts(ForumAuthor updatedAuthor) {
    _postsById.updateAll((String key, ForumPost post) {
      if (post.author.id != updatedAuthor.id) return post;
      return post.copyWith(
        author: updatedAuthor,
        showFollowButton:
            updatedAuthor.id != currentUserId && !updatedAuthor.isFollowing,
      );
    });

    _commentsByPostId.updateAll((String key, List<ForumComment> comments) {
      return comments
          .map((ForumComment comment) {
            if (comment.author.id != updatedAuthor.id) return comment;
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

  Future<void> _persistAndRefresh(Future<void> Function() action) async {
    try {
      await action();
      await refresh(notifyLoading: false);
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Save forum data error: $error');
      await refresh(notifyLoading: false);
    }
  }
}
