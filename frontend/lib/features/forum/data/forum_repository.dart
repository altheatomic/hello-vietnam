import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/media/cloudflare_media_repository.dart';
import '../domain/create_forum_post_request.dart';
import '../domain/forum_models.dart';
import 'forum_page_cursor.dart';
import 'forum_rpc_row_mapper.dart';

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
    this.nextForYouCursor,
    this.nextFollowingCursor,
    this.hasMoreForYou = false,
    this.hasMoreFollowing = false,
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
  final ForumPageCursor? nextForYouCursor;
  final ForumPageCursor? nextFollowingCursor;
  final bool hasMoreForYou;
  final bool hasMoreFollowing;
}

class ForumCommentsPage {
  const ForumCommentsPage({
    required this.comments,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ForumComment> comments;
  final ForumPageCursor? nextCursor;
  final bool hasMore;
}

class ForumRepository {
  ForumRepository({
    SupabaseClient? client,
    CloudflareMediaRepository? mediaRepository,
    ForumRpcRowMapper rowMapper = const ForumRpcRowMapper(),
  }) : _client = client ?? Supabase.instance.client,
       _mediaRepository = mediaRepository,
       _rowMapper = rowMapper;

  final SupabaseClient _client;
  final ForumRpcRowMapper _rowMapper;
  CloudflareMediaRepository? _mediaRepository;

  User? get _authUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  CloudflareMediaRepository get _mediaUploader =>
      _mediaRepository ??= CloudflareMediaRepository();

  Future<ForumRepositorySnapshot> loadSnapshot({
    ForumPageCursor? beforeForYouCursor,
    ForumPageCursor? beforeFollowingCursor,
    int limit = 20,
    bool loadForYouPage = true,
    bool loadFollowingPage = true,
    bool includeNotifications = true,
  }) async {
    final String currentUserId = await _requireForumUser();
    final List<List<Map<String, dynamic>>> pages =
        await Future.wait(<Future<List<Map<String, dynamic>>>>[
          if (loadForYouPage)
            _loadFeedPage(
              feed: 'for_you',
              beforeCursor: beforeForYouCursor,
              limit: limit,
            )
          else
            Future<List<Map<String, dynamic>>>.value(
              const <Map<String, dynamic>>[],
            ),
          if (loadFollowingPage)
            _loadFeedPage(
              feed: 'following',
              beforeCursor: beforeFollowingCursor,
              limit: limit,
            )
          else
            Future<List<Map<String, dynamic>>>.value(
              const <Map<String, dynamic>>[],
            ),
        ]);
    final List<Map<String, dynamic>> forYouPostRows = pages[0];
    final List<Map<String, dynamic>> followingPostRows = pages[1];

    final Map<String, Map<String, dynamic>> postRowsById =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row in <Map<String, dynamic>>[
      ...forYouPostRows,
      ...followingPostRows,
    ]) {
      final String postId = _stringValue(row['id_post']);
      if (postId.isNotEmpty) {
        postRowsById[postId] = row;
      }
    }
    final List<ForumMappedFeedRow> mappedRows = postRowsById.values
        .map(
          (Map<String, dynamic> row) =>
              _rowMapper.mapFeedRow(row, currentUserId: currentUserId),
        )
        .toList(growable: false);
    final List<ForumPost> posts = mappedRows
        .map((ForumMappedFeedRow row) => row.post)
        .toList(growable: false);
    final Map<String, ForumUserProfile> profilesById =
        <String, ForumUserProfile>{
          for (final ForumMappedFeedRow row in mappedRows)
            row.profile.author.id: row.profile,
        };
    profilesById[currentUserId] =
        profilesById[currentUserId] ??
        await _loadCurrentUserProfile(currentUserId);

    final List<String> forYouFeedIds = forYouPostRows
        .map((Map<String, dynamic> row) => _stringValue(row['id_post']))
        .where((String postId) => postRowsById.containsKey(postId))
        .toList(growable: false);
    final List<String> followingFeedIds = followingPostRows
        .map((Map<String, dynamic> row) => _stringValue(row['id_post']))
        .where((String postId) => postRowsById.containsKey(postId))
        .toList(growable: false);

    return ForumRepositorySnapshot(
      currentUserId: currentUserId,
      currentUserProfile:
          profilesById[currentUserId] ??
          _fallbackProfile(currentUserId, currentUserId: currentUserId),
      profilesById: profilesById,
      posts: posts,
      commentsByPostId: const <String, List<ForumComment>>{},
      forYouFeedIds: forYouFeedIds,
      followingFeedIds: followingFeedIds,
      notifications: includeNotifications
          ? await _loadNotifications(profilesById)
          : const <ForumNotificationItem>[],
      blockedAuthorIds: const <String>{},
      reportedPostIds: mappedRows
          .where((ForumMappedFeedRow row) => row.isReported)
          .map((ForumMappedFeedRow row) => row.post.id)
          .toSet(),
      nextForYouCursor: _nextCursor(
        forYouPostRows,
        limit: limit,
        idKey: 'id_post',
      ),
      nextFollowingCursor: _nextCursor(
        followingPostRows,
        limit: limit,
        idKey: 'id_post',
      ),
      hasMoreForYou: forYouPostRows.length == limit,
      hasMoreFollowing: followingPostRows.length == limit,
    );
  }

  Future<ForumCommentsPage> loadCommentsPage({
    required String postId,
    ForumPageCursor? beforeCursor,
    int limit = 20,
  }) async {
    await _requireForumUser();
    final Map<String, dynamic> arguments = <String, dynamic>{
      'p_post_id': postId,
      'p_limit': limit,
      'p_before_created_at': null,
      'p_before_comment_id': null,
      ...?beforeCursor?.toRpcArguments(
        createdAtKey: 'p_before_created_at',
        idKey: 'p_before_comment_id',
      ),
    };
    final List<Map<String, dynamic>> rows = _normalizeRows(
      await _client.rpc('forum_comments_page', params: arguments),
    );
    return ForumCommentsPage(
      comments: rows.map(_rowMapper.mapCommentRow).toList(growable: false),
      nextCursor: _nextCursor(rows, limit: limit, idKey: 'id_comment'),
      hasMore: rows.length == limit,
    );
  }

  Future<List<Map<String, dynamic>>> _loadFeedPage({
    required String feed,
    required ForumPageCursor? beforeCursor,
    required int limit,
  }) async {
    final Map<String, dynamic> arguments = <String, dynamic>{
      'p_feed': feed,
      'p_limit': limit,
      'p_before_created_at': null,
      'p_before_post_id': null,
      ...?beforeCursor?.toRpcArguments(
        createdAtKey: 'p_before_created_at',
        idKey: 'p_before_post_id',
      ),
    };
    return _normalizeRows(
      await _client.rpc('forum_feed_page', params: arguments),
    );
  }

  ForumPageCursor? _nextCursor(
    List<Map<String, dynamic>> rows, {
    required int limit,
    required String idKey,
  }) {
    if (rows.length < limit || rows.isEmpty) return null;
    return ForumPageCursor.fromRow(rows.last, idKey: idKey);
  }

  List<Map<String, dynamic>> _normalizeRows(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> row) => row.map(
            (dynamic key, dynamic innerValue) =>
                MapEntry<String, dynamic>(key.toString(), innerValue),
          ),
        )
        .toList(growable: false);
  }

  Future<ForumUserProfile> _loadCurrentUserProfile(String userId) async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('user_account')
          .select('id_user, full_name, username, avatar, role')
          .eq('id_user', userId)
          .maybeSingle(),
      _client
          .from('forum_user_follow')
          .select('follower_user_id')
          .eq('following_user_id', userId)
          .limit(1)
          .count(CountOption.exact),
      _client
          .from('forum_user_follow')
          .select('following_user_id')
          .eq('follower_user_id', userId)
          .limit(1)
          .count(CountOption.exact),
    ]);
    final Object? rawProfile = results[0];
    if (rawProfile is! Map) {
      return _fallbackProfile(userId, currentUserId: userId);
    }
    final Map<String, dynamic> profile = rawProfile.map(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    return _profileFromRow(
      profile,
      currentUserId: userId,
      isFollowing: false,
      followersCount: _responseCount(results[1]),
      followingCount: _responseCount(results[2]),
    );
  }

  int _responseCount(Object? response) {
    try {
      final dynamic count = (response as dynamic).count;
      return count is num ? count.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String> createPost({
    required String content,
    required List<String> imageUrls,
    List<XFile> imageFiles = const <XFile>[],
    SharedExploreItem? sharedExploreItem,
  }) async {
    final String userId = await _requireForumUser();
    final Map<String, dynamic> row = await _client
        .from('forum_post')
        .insert(<String, dynamic>{
          'id_author_user': userId,
          if (sharedExploreItem != null) 'title': sharedExploreItem.title,
          'content': content.trim(),
          'shared_item': sharedExploreItem?.toJson(),
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

  Future<List<String>> updatePost({
    required String postId,
    required String content,
    required List<String> retainedImageUrls,
    List<XFile> imageFiles = const <XFile>[],
  }) async {
    final String userId = await _requireForumUser();
    final List<dynamic> mediaRows = await _client
        .from('forum_post_media')
        .select('id_media, url, position')
        .eq('id_post', postId)
        .order('position');
    final Map<String, Map<String, dynamic>> mediaByUrl =
        <String, Map<String, dynamic>>{
          for (final dynamic rawRow in mediaRows)
            if (rawRow is Map)
              _stringValue(rawRow['url']): rawRow.map(
                (dynamic key, dynamic value) =>
                    MapEntry<String, dynamic>(key.toString(), value),
              ),
        }..remove('');

    final List<String> retainedUrls = retainedImageUrls
        .map((String url) => url.trim())
        .where(mediaByUrl.containsKey)
        .toSet()
        .take(6)
        .toList(growable: false);
    final List<XFile> newImages = imageFiles
        .take(6 - retainedUrls.length)
        .toList(growable: false);

    final List<dynamic> updatedRows = await _client
        .from('forum_post')
        .update(<String, dynamic>{
          'content': content.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id_post', postId)
        .eq('id_author_user', userId)
        .select('id_post');
    if (updatedRows.isEmpty) {
      throw StateError('Post not found or you cannot edit this post.');
    }

    for (int index = 0; index < retainedUrls.length; index++) {
      final String mediaId = _stringValue(
        mediaByUrl[retainedUrls[index]]?['id_media'],
      );
      if (mediaId.isEmpty) continue;
      await _client
          .from('forum_post_media')
          .update(<String, dynamic>{'position': index})
          .eq('id_media', mediaId)
          .eq('id_post', postId);
    }

    final List<String> removedUrls = mediaByUrl.keys
        .where((String url) => !retainedUrls.contains(url))
        .toList(growable: false);
    if (removedUrls.isNotEmpty) {
      final List<String> removedIds = removedUrls
          .map((String url) => _stringValue(mediaByUrl[url]?['id_media']))
          .where((String id) => id.isNotEmpty)
          .toList(growable: false);
      if (removedIds.isNotEmpty) {
        await _client
            .from('forum_post_media')
            .delete()
            .eq('id_post', postId)
            .inFilter('id_media', removedIds);
      }
    }

    List<String> uploadedUrls = const <String>[];
    if (newImages.isNotEmpty) {
      uploadedUrls = await _uploadPostImages(
        userId: userId,
        postId: postId,
        imageFiles: newImages,
      );
      try {
        await _client.from('forum_post_media').insert(<Map<String, dynamic>>[
          for (int index = 0; index < uploadedUrls.length; index++)
            <String, dynamic>{
              'id_post': postId,
              'url': uploadedUrls[index],
              'position': retainedUrls.length + index,
            },
        ]);
      } catch (_) {
        await _deleteMediaUrls(uploadedUrls);
        rethrow;
      }
    }

    await _deleteMediaUrls(removedUrls);
    return <String>[...retainedUrls, ...uploadedUrls];
  }

  Future<void> deletePost(String postId) async {
    final String userId = await _requireForumUser();
    final List<dynamic> mediaRows = await _client
        .from('forum_post_media')
        .select('url')
        .eq('id_post', postId);
    final List<String> mediaUrls = mediaRows
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => _stringValue(row['url']))
        .where((String url) => url.isNotEmpty)
        .toList(growable: false);

    final List<dynamic> deletedRows = await _client
        .from('forum_post')
        .delete()
        .eq('id_post', postId)
        .eq('id_author_user', userId)
        .select('id_post');
    if (deletedRows.isEmpty) {
      throw StateError('Post not found or you cannot delete this post.');
    }

    await _deleteMediaUrls(mediaUrls);
  }

  Future<void> _deleteMediaUrls(Iterable<String> urls) async {
    final List<String> keys = urls
        .map(_mediaUploader.keyFromUrlOrPath)
        .whereType<String>()
        .toList(growable: false);
    await _mediaUploader.deleteKeys(keys);
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
      final CloudflareMediaUpload uploaded = await _mediaUploader.uploadBytes(
        bytes: bytes,
        folder: 'forum/$userId/$postId',
        fileName: '${DateTime.now().microsecondsSinceEpoch}_$i$extension',
        contentType: file.mimeType ?? _mimeTypeFromExtension(extension),
      );
      urls.add(uploaded.url);
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
