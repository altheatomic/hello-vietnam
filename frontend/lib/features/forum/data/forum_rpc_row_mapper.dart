import '../domain/create_forum_post_request.dart';
import '../domain/forum_models.dart';

class ForumMappedFeedRow {
  const ForumMappedFeedRow({
    required this.post,
    required this.profile,
    required this.isReported,
  });

  final ForumPost post;
  final ForumUserProfile profile;
  final bool isReported;
}

class ForumRpcRowMapper {
  const ForumRpcRowMapper();

  ForumMappedFeedRow mapFeedRow(
    Map<String, dynamic> row, {
    required String currentUserId,
  }) {
    final String authorId = _stringValue(row['id_author_user']);
    final bool isFollowing = _boolValue(row['is_following']);
    final ForumUserProfile profile = ForumUserProfile(
      author: ForumAuthor(
        id: authorId,
        name: _displayName(row),
        handle: '@${_handleFrom(_authorIdentity(row))}',
        avatarUrl: _stringValue(row['author_avatar']),
        isVerified: _stringValue(row['author_role']) == 'admin',
        isFollowing: isFollowing,
      ),
      followersCount: _intValue(row['author_follower_count']),
      followingCount: _intValue(row['author_following_count']),
      isCurrentUser: authorId == currentUserId,
    );

    final Map<String, dynamic>? sharedItem = _normalizedMap(row['shared_item']);
    return ForumMappedFeedRow(
      post: ForumPost(
        id: _stringValue(row['id_post']),
        author: profile.author,
        content: _stringValue(row['content']),
        imageUrls: _stringList(row['image_urls']),
        timeAgo: _timeAgo(row['created_at']),
        likes: _intValue(row['like_count']),
        comments: _intValue(row['comment_count']),
        sharedItem: sharedItem == null || sharedItem['type'] == 'trip_plan'
            ? null
            : SharedExploreItem.fromJson(sharedItem),
        sharedTripPlan: sharedItem == null || sharedItem['type'] != 'trip_plan'
            ? null
            : SharedTripPlanItem.fromJson(sharedItem),
        isLiked: _boolValue(row['is_liked']),
        isBookmarked: _boolValue(row['is_bookmarked']),
        showFollowButton: authorId != currentUserId && !isFollowing,
      ),
      profile: profile,
      isReported: _boolValue(row['is_reported']),
    );
  }

  ForumComment mapCommentRow(Map<String, dynamic> row) {
    final String username = _stringValue(row['author_username']);
    final String name = _displayName(row);
    return ForumComment(
      id: _stringValue(row['id_comment']),
      author: ForumAuthor(
        id: _stringValue(row['id_author_user']),
        name: name,
        handle: '@${_handleFrom(username.isNotEmpty ? username : name)}',
        avatarUrl: _stringValue(row['author_avatar']),
        isVerified: _stringValue(row['author_role']) == 'admin',
      ),
      content: _stringValue(row['content']),
      timeAgo: _timeAgo(row['created_at']),
      likes: _intValue(row['like_count']),
      isLiked: _boolValue(row['is_liked']),
    );
  }

  String _displayName(Map<String, dynamic> row) {
    final String name = _stringValue(row['author_name']);
    if (name.isNotEmpty) return name;
    final String username = _stringValue(row['author_username']);
    return username.isEmpty ? 'Forum user' : username.split('@').first;
  }

  String _authorIdentity(Map<String, dynamic> row) {
    final String username = _stringValue(row['author_username']);
    return username.isNotEmpty ? username : _displayName(row);
  }

  String _stringValue(Object? value) => value?.toString().trim() ?? '';

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(_stringValue(value)) ?? 0;
  }

  bool _boolValue(Object? value) {
    if (value is bool) return value;
    return _stringValue(value).toLowerCase() == 'true';
  }

  List<String> _stringList(Object? value) {
    if (value is! Iterable) return const <String>[];
    return value
        .map(_stringValue)
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic>? _normalizedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic innerValue) =>
            MapEntry<String, dynamic>(key.toString(), innerValue),
      );
    }
    return null;
  }

  String _handleFrom(String value) {
    final String normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'@.*$'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'forum_user' : normalized;
  }

  String _timeAgo(Object? value) {
    final DateTime? createdAt = DateTime.tryParse(_stringValue(value));
    if (createdAt == null) return 'now';
    final Duration diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final int weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
