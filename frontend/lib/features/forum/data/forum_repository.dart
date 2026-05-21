import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../domain/forum_models.dart';

class ForumRepositorySnapshot {
  const ForumRepositorySnapshot({
    required this.currentUserId,
    required this.currentUserProfile,
    required this.profilesById,
    required this.posts,
    required this.commentsByPostId,
    required this.forYouFeedIds,
    required this.followingFeedIds,
    required this.notifications,
    required this.blockedAuthorIds,
    required this.reportedPostIds,
  });

  final String currentUserId;
  final ForumUserProfile currentUserProfile;
  final Map<String, ForumUserProfile> profilesById;
  final List<ForumPost> posts;
  final Map<String, List<ForumComment>> commentsByPostId;
  final List<String> forYouFeedIds;
  final List<String> followingFeedIds;
  final List<ForumNotificationItem> notifications;
  final Set<String> blockedAuthorIds;
  final Set<String> reportedPostIds;
}

class ForumRepository {
  ForumRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get _authUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<ForumRepositorySnapshot> loadSnapshot() async {
    final String currentUserId = await _requireForumUser();

    final List<Map<String, dynamic>> postRows = await _client
        .from('forum_post')
        .select('id_post, id_author_user, title, content, created_at, status')
        .or('status.is.null,status.eq.active')
        .order('created_at', ascending: false)
        .limit(80);

    final List<String> postIds = postRows
        .map((Map<String, dynamic> row) => _stringValue(row['id_post']))
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);

    final List<String> authorIds = postRows
        .map((Map<String, dynamic> row) => _stringValue(row['id_author_user']))
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    final List<Map<String, dynamic>> commentRows = postIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('forum_comment')
              .select(
                'id_comment, id_post, id_author_user, content, created_at, status',
              )
              .inFilter('id_post', postIds)
              .or('status.is.null,status.eq.active')
              .order('created_at', ascending: false);

    authorIds.addAll(
      commentRows
          .map(
            (Map<String, dynamic> row) => _stringValue(row['id_author_user']),
          )
          .where((String id) => id.isNotEmpty),
    );

    final List<Map<String, dynamic>> mediaRows = postIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _optionalRows(
            () => _client
                .from('forum_post_media')
                .select('id_post, url, position')
                .inFilter('id_post', postIds)
                .order('position'),
            source: 'forum_post_media',
          );

    final List<Map<String, dynamic>> likedPostRows = postIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _optionalRows(
            () => _client
                .from('forum_post_like')
                .select('id_post, id_user')
                .inFilter('id_post', postIds),
            source: 'forum_post_like',
          );

    final List<String> commentIds = commentRows
        .map((Map<String, dynamic> row) => _stringValue(row['id_comment']))
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);

    final List<Map<String, dynamic>> likedCommentRows = commentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _optionalRows(
            () => _client
                .from('forum_comment_like')
                .select('id_comment, id_user')
                .inFilter('id_comment', commentIds),
            source: 'forum_comment_like',
          );

    final List<Map<String, dynamic>> bookmarkRows = postIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _optionalRows(
            () => _client
                .from('forum_post_bookmark')
                .select('id_post, id_user')
                .eq('id_user', currentUserId)
                .inFilter('id_post', postIds),
            source: 'forum_post_bookmark',
          );

    final List<Map<String, dynamic>> followingRows = await _optionalRows(
      () => _client
          .from('forum_user_follow')
          .select('following_user_id')
          .eq('follower_user_id', currentUserId),
      source: 'forum_user_follow',
    );

    final List<Map<String, dynamic>> followerRows = authorIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _optionalRows(
            () => _client
                .from('forum_user_follow')
                .select('following_user_id, follower_user_id')
                .inFilter('following_user_id', authorIds.toSet().toList()),
            source: 'forum_user_follow',
          );

    final List<Map<String, dynamic>> blockedRows = await _optionalRows(
      () => _client
          .from('forum_user_block')
          .select('blocked_user_id')
          .eq('blocker_user_id', currentUserId),
      source: 'forum_user_block',
    );

    final List<Map<String, dynamic>> reportRows = postIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _optionalRows(
            () => _client
                .from('forum_post_report')
                .select('id_post')
                .eq('id_reporter_user', currentUserId)
                .inFilter('id_post', postIds),
            source: 'forum_post_report',
          );

    final Set<String> followingIds = followingRows
        .map(
          (Map<String, dynamic> row) => _stringValue(row['following_user_id']),
        )
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> blockedIds = blockedRows
        .map((Map<String, dynamic> row) => _stringValue(row['blocked_user_id']))
        .where((String id) => id.isNotEmpty)
        .toSet();

    authorIds
      ..add(currentUserId)
      ..addAll(followingIds);
    final Map<String, ForumUserProfile> profilesById = await _loadProfiles(
      authorIds.toSet().toList(),
      currentUserId: currentUserId,
      followingIds: followingIds,
      followerRows: followerRows,
    );

    final Map<String, List<String>> imageUrlsByPostId =
        <String, List<String>>{};
    for (final Map<String, dynamic> row in mediaRows) {
      final String postId = _stringValue(row['id_post']);
      final String url = _stringValue(row['url']);
      if (postId.isNotEmpty && url.isNotEmpty) {
        imageUrlsByPostId.putIfAbsent(postId, () => <String>[]).add(url);
      }
    }

    final Map<String, int> likeCountByPostId = _countBy(
      likedPostRows,
      'id_post',
    );
    final Set<String> likedPostIds = likedPostRows
        .where(
          (Map<String, dynamic> row) =>
              _stringValue(row['id_user']) == currentUserId,
        )
        .map((Map<String, dynamic> row) => _stringValue(row['id_post']))
        .toSet();
    final Set<String> bookmarkedPostIds = bookmarkRows
        .map((Map<String, dynamic> row) => _stringValue(row['id_post']))
        .toSet();

    final Map<String, int> commentCountByPostId = _countBy(
      commentRows,
      'id_post',
    );
    final Map<String, List<ForumComment>> commentsByPostId = _buildComments(
      commentRows: commentRows,
      profilesById: profilesById,
      likeCountByCommentId: _countBy(likedCommentRows, 'id_comment'),
      likedCommentIds: likedCommentRows
          .where(
            (Map<String, dynamic> row) =>
                _stringValue(row['id_user']) == currentUserId,
          )
          .map((Map<String, dynamic> row) => _stringValue(row['id_comment']))
          .toSet(),
    );

    final List<ForumPost> posts = postRows
        .map((Map<String, dynamic> row) {
          final String postId = _stringValue(row['id_post']);
          final String authorId = _stringValue(row['id_author_user']);
          final ForumAuthor author =
              profilesById[authorId]?.author ??
              _fallbackProfile(authorId, currentUserId: currentUserId).author;
          return ForumPost(
            id: postId,
            author: author,
            content: _stringValue(row['content']),
            imageUrls: imageUrlsByPostId[postId] ?? const <String>[],
            timeAgo: _timeAgo(row['created_at']),
            likes: likeCountByPostId[postId] ?? 0,
            comments: commentCountByPostId[postId] ?? 0,
            isLiked: likedPostIds.contains(postId),
            isBookmarked: bookmarkedPostIds.contains(postId),
            showFollowButton: authorId != currentUserId && !author.isFollowing,
          );
        })
        .toList(growable: false);

    final List<String> forYouFeedIds = posts
        .where((ForumPost post) => !blockedIds.contains(post.author.id))
        .map((ForumPost post) => post.id)
        .toList(growable: false);
    final List<String> followingFeedIds = posts
        .where((ForumPost post) => followingIds.contains(post.author.id))
        .map((ForumPost post) => post.id)
        .toList(growable: false);

    return ForumRepositorySnapshot(
      currentUserId: currentUserId,
      currentUserProfile:
          profilesById[currentUserId] ??
          _fallbackProfile(currentUserId, currentUserId: currentUserId),
      profilesById: profilesById,
      posts: posts,
      commentsByPostId: commentsByPostId,
      forYouFeedIds: forYouFeedIds,
      followingFeedIds: followingFeedIds,
      notifications: await _loadNotifications(profilesById),
      blockedAuthorIds: blockedIds,
      reportedPostIds: reportRows
          .map((Map<String, dynamic> row) => _stringValue(row['id_post']))
          .toSet(),
    );
  }

  Future<String> createPost({
    required String content,
    required List<String> imageUrls,
    List<XFile> imageFiles = const <XFile>[],
  }) async {
    final String userId = await _requireForumUser();
    final Map<String, dynamic> row = await _client
        .from('forum_post')
        .insert(<String, dynamic>{
          'id_author_user': userId,
          'content': content.trim(),
          'status': 'active',
        })
        .select('id_post')
        .single();
    final String postId = _stringValue(row['id_post']);

    List<String> uploadedImageUrls;
    if (imageFiles.isEmpty) {
      uploadedImageUrls = const <String>[];
    } else {
      try {
        uploadedImageUrls = await _uploadPostImages(
          userId: userId,
          postId: postId,
          imageFiles: imageFiles,
        );
      } catch (error) {
        debugPrint('Upload forum media warning: $error');
        uploadedImageUrls = const <String>[];
      }
    }
    final List<String> allImageUrls = <String>[
      ...imageUrls,
      ...uploadedImageUrls,
    ];

    if (allImageUrls.isNotEmpty) {
      try {
        await _client.from('forum_post_media').insert(<Map<String, dynamic>>[
          for (int i = 0; i < allImageUrls.length; i++)
            <String, dynamic>{
              'id_post': postId,
              'url': allImageUrls[i],
              'position': i,
            },
        ]);
      } catch (error) {
        debugPrint('Save forum media warning: $error');
      }
    }

    return postId;
  }

  Future<List<String>> _uploadPostImages({
    required String userId,
    required String postId,
    required List<XFile> imageFiles,
  }) async {
    final List<String> urls = <String>[];
    for (int i = 0; i < imageFiles.length; i++) {
      final XFile file = imageFiles[i];
      final Uint8List bytes = await file.readAsBytes();
      final String extension = _extensionFrom(
        file.name.isNotEmpty ? file.name : file.path,
      );
      final String path =
          '$userId/$postId/${DateTime.now().microsecondsSinceEpoch}_$i$extension';

      await _client.storage
          .from(Env.forumMediaBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: file.mimeType ?? _mimeTypeFromExtension(extension),
              upsert: true,
            ),
          );
      urls.add(_client.storage.from(Env.forumMediaBucket).getPublicUrl(path));
    }
    return urls;
  }

  Future<void> addReply({
    required String postId,
    required String content,
  }) async {
    final String userId = await _requireForumUser();
    await _client.from('forum_comment').insert(<String, dynamic>{
      'id_post': postId,
      'id_author_user': userId,
      'content': content.trim(),
      'status': 'active',
    });
  }

  Future<void> setPostLiked({
    required String postId,
    required bool liked,
  }) async {
    final String userId = await _requireForumUser();
    if (liked) {
      await _client.from('forum_post_like').upsert(<String, dynamic>{
        'id_post': postId,
        'id_user': userId,
      });
      return;
    }

    await _client
        .from('forum_post_like')
        .delete()
        .eq('id_post', postId)
        .eq('id_user', userId);
  }

  Future<void> setCommentLiked({
    required String commentId,
    required bool liked,
  }) async {
    final String userId = await _requireForumUser();
    if (liked) {
      await _client.from('forum_comment_like').upsert(<String, dynamic>{
        'id_comment': commentId,
        'id_user': userId,
      });
      return;
    }

    await _client
        .from('forum_comment_like')
        .delete()
        .eq('id_comment', commentId)
        .eq('id_user', userId);
  }

  Future<void> setBookmarked({
    required String postId,
    required bool bookmarked,
  }) async {
    final String userId = await _requireForumUser();
    if (bookmarked) {
      await _client.from('forum_post_bookmark').upsert(<String, dynamic>{
        'id_post': postId,
        'id_user': userId,
      });
      return;
    }

    await _client
        .from('forum_post_bookmark')
        .delete()
        .eq('id_post', postId)
        .eq('id_user', userId);
  }

  Future<void> setFollowing({
    required String authorId,
    required bool following,
  }) async {
    final String userId = await _requireForumUser();
    if (following) {
      await _client.from('forum_user_follow').upsert(<String, dynamic>{
        'follower_user_id': userId,
        'following_user_id': authorId,
      });
      return;
    }

    await _client
        .from('forum_user_follow')
        .delete()
        .eq('follower_user_id', userId)
        .eq('following_user_id', authorId);
  }

  Future<void> setBlocked({
    required String authorId,
    required bool blocked,
  }) async {
    final String userId = await _requireForumUser();
    if (blocked) {
      await _client.from('forum_user_block').upsert(<String, dynamic>{
        'blocker_user_id': userId,
        'blocked_user_id': authorId,
      });
      await setFollowing(authorId: authorId, following: false);
      return;
    }

    await _client
        .from('forum_user_block')
        .delete()
        .eq('blocker_user_id', userId)
        .eq('blocked_user_id', authorId);
  }

  Future<void> submitReport({
    required String postId,
    required String reason,
    String? details,
  }) async {
    final String userId = await _requireForumUser();
    await _client.from('forum_post_report').insert(<String, dynamic>{
      'id_post': postId,
      'id_reporter_user': userId,
      'reason': reason,
      'details': details,
    });
  }

  Future<String> _requireForumUser() async {
    final User? user = _authUser;
    if (user == null) {
      throw StateError('Please sign in before using the forum.');
    }

    final String userId = user.id;
    final String? email = user.email?.trim();
    final String? fullName = (user.userMetadata?['full_name'] as String?)
        ?.trim();

    final Map<String, dynamic>? existing = await _client
        .from('user_account')
        .select('id_user, full_name, username')
        .eq('id_user', userId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('user_account').insert(<String, dynamic>{
        'id_user': userId,
        'full_name': fullName,
        'username': email,
      });
    } else {
      final String existingFullName = _stringValue(existing['full_name']);
      final String existingUsername = _stringValue(existing['username']);
      if ((existingFullName.isEmpty &&
              fullName != null &&
              fullName.isNotEmpty) ||
          (existingUsername.isEmpty && email != null && email.isNotEmpty)) {
        await _client
            .from('user_account')
            .update(<String, dynamic>{
              if (existingFullName.isEmpty &&
                  fullName != null &&
                  fullName.isNotEmpty)
                'full_name': fullName,
              if (existingUsername.isEmpty && email != null && email.isNotEmpty)
                'username': email,
            })
            .eq('id_user', userId);
      }
    }

    return userId;
  }

  Future<Map<String, ForumUserProfile>> _loadProfiles(
    List<String> userIds, {
    required String currentUserId,
    required Set<String> followingIds,
    required List<Map<String, dynamic>> followerRows,
  }) async {
    if (userIds.isEmpty) return <String, ForumUserProfile>{};

    final List<Map<String, dynamic>> rows = await _client
        .from('user_account')
        .select('id_user, full_name, username, avatar, role')
        .inFilter('id_user', userIds.toSet().toList());

    final Map<String, int> followersByUserId = _countBy(
      followerRows,
      'following_user_id',
    );
    final Map<String, int> followingByUserId = _countBy(
      followerRows,
      'follower_user_id',
    );

    final Map<String, ForumUserProfile> profiles = <String, ForumUserProfile>{
      for (final Map<String, dynamic> row in rows)
        _stringValue(row['id_user']): _profileFromRow(
          row,
          currentUserId: currentUserId,
          isFollowing: followingIds.contains(_stringValue(row['id_user'])),
          followersCount: followersByUserId[_stringValue(row['id_user'])] ?? 0,
          followingCount: followingByUserId[_stringValue(row['id_user'])] ?? 0,
        ),
    };

    for (final String userId in userIds.toSet()) {
      if (userId.isEmpty || profiles.containsKey(userId)) continue;

      profiles[userId] = _fallbackProfile(
        userId,
        currentUserId: currentUserId,
        isFollowing: followingIds.contains(userId),
        followersCount: followersByUserId[userId] ?? 0,
        followingCount: followingByUserId[userId] ?? 0,
      );
    }

    return profiles;
  }

  Future<List<ForumNotificationItem>> _loadNotifications(
    Map<String, ForumUserProfile> profilesById,
  ) async {
    final User? user = _authUser;
    if (user == null) return const <ForumNotificationItem>[];

    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('notification')
          .select('id_notification, title, body, deeplink, created_at')
          .eq('id_user', user.id)
          .eq('is_in_app', true)
          .order('created_at', ascending: false)
          .limit(30);

      return rows
          .map((Map<String, dynamic> row) {
            final String deeplink = _stringValue(row['deeplink']);
            return ForumNotificationItem(
              id: _stringValue(row['id_notification']),
              actor:
                  profilesById[user.id]?.author ??
                  _fallbackProfile(user.id, currentUserId: user.id).author,
              message: _stringValue(row['body']).isEmpty
                  ? _stringValue(row['title'])
                  : _stringValue(row['body']),
              timeAgo: _timeAgo(row['created_at']),
              postId: _postIdFromDeeplink(deeplink),
            );
          })
          .toList(growable: false);
    } catch (error) {
      debugPrint('Load forum notifications warning: $error');
      return const <ForumNotificationItem>[];
    }
  }

  Map<String, List<ForumComment>> _buildComments({
    required List<Map<String, dynamic>> commentRows,
    required Map<String, ForumUserProfile> profilesById,
    required Map<String, int> likeCountByCommentId,
    required Set<String> likedCommentIds,
  }) {
    final Map<String, List<ForumComment>> commentsByPostId =
        <String, List<ForumComment>>{};
    for (final Map<String, dynamic> row in commentRows) {
      final String postId = _stringValue(row['id_post']);
      final String commentId = _stringValue(row['id_comment']);
      final String authorId = _stringValue(row['id_author_user']);
      final ForumAuthor author =
          profilesById[authorId]?.author ??
          _fallbackProfile(authorId, currentUserId: '').author;
      commentsByPostId
          .putIfAbsent(postId, () => <ForumComment>[])
          .add(
            ForumComment(
              id: commentId,
              author: author,
              content: _stringValue(row['content']),
              timeAgo: _timeAgo(row['created_at']),
              likes: likeCountByCommentId[commentId] ?? 0,
              isLiked: likedCommentIds.contains(commentId),
            ),
          );
    }
    return commentsByPostId;
  }

  ForumUserProfile _profileFromRow(
    Map<String, dynamic> row, {
    required String currentUserId,
    required bool isFollowing,
    required int followersCount,
    required int followingCount,
  }) {
    final String id = _stringValue(row['id_user']);
    final String username = _stringValue(row['username']);
    final String fullName = _stringValue(row['full_name']);
    final String displayName = fullName.isNotEmpty
        ? fullName
        : (username.isNotEmpty ? username.split('@').first : 'Forum user');
    return ForumUserProfile(
      author: ForumAuthor(
        id: id,
        name: displayName,
        handle: '@${_handleFrom(username.isNotEmpty ? username : displayName)}',
        avatarUrl: _stringValue(row['avatar']),
        isVerified: _stringValue(row['role']) == 'admin',
        isFollowing: isFollowing,
      ),
      followersCount: followersCount,
      followingCount: followingCount,
      isCurrentUser: id == currentUserId,
    );
  }

  ForumUserProfile _fallbackProfile(
    String userId, {
    required String currentUserId,
    bool isFollowing = false,
    int followersCount = 0,
    int followingCount = 0,
  }) {
    final String shortId = userId.isEmpty
        ? 'forum'
        : userId.substring(0, userId.length < 8 ? userId.length : 8);
    return ForumUserProfile(
      author: ForumAuthor(
        id: userId,
        name: userId == currentUserId ? 'You' : 'User $shortId',
        handle: '@$shortId',
        avatarUrl: '',
        isFollowing: isFollowing,
      ),
      followersCount: followersCount,
      followingCount: followingCount,
      isCurrentUser: userId == currentUserId,
    );
  }

  Map<String, int> _countBy(List<Map<String, dynamic>> rows, String key) {
    final Map<String, int> counts = <String, int>{};
    for (final Map<String, dynamic> row in rows) {
      final String value = _stringValue(row[key]);
      if (value.isNotEmpty) {
        counts[value] = (counts[value] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> _optionalRows(
    Future<List<Map<String, dynamic>>> Function() load, {
    required String source,
  }) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('Load optional forum table $source warning: $error');
      return <Map<String, dynamic>>[];
    }
  }

  String _stringValue(Object? value) => value?.toString().trim() ?? '';

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

  String? _postIdFromDeeplink(String deeplink) {
    if (deeplink.isEmpty) return null;
    final Uri? uri = Uri.tryParse(deeplink);
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final int postIndex = segments.indexOf('post');
    if (postIndex == -1 || postIndex == segments.length - 1) return null;
    return segments[postIndex + 1];
  }

  String _extensionFrom(String source) {
    final int dotIndex = source.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == source.length - 1) {
      return '.jpg';
    }
    return source.substring(dotIndex).toLowerCase();
  }

  String _mimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.jpeg':
      case '.jpg':
      default:
        return 'image/jpeg';
    }
  }
}
