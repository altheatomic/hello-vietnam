import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/data/forum_rpc_row_mapper.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  const ForumRpcRowMapper mapper = ForumRpcRowMapper();

  test('maps an aggregated feed row without client-side joins', () {
    final ForumMappedFeedRow result = mapper.mapFeedRow(<String, dynamic>{
      'id_post': 'post-1',
      'id_author_user': 'user-2',
      'content': 'A real forum post',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'author_name': 'Lan Nguyen',
      'author_username': 'lan@example.com',
      'author_avatar': 'https://cdn.example/avatar.jpg',
      'author_role': 'admin',
      'author_follower_count': '12',
      'author_following_count': 4,
      'image_urls': <dynamic>[
        'https://cdn.example/one.jpg',
        '',
        null,
        'https://cdn.example/two.jpg',
      ],
      'like_count': 8.0,
      'comment_count': '3',
      'is_liked': true,
      'is_bookmarked': true,
      'is_following': false,
      'is_reported': true,
      'shared_item': <String, dynamic>{
        'contentType': 'food',
        'contentId': 'food-1',
        'provinceId': 'province-1',
        'title': 'Bun bo Hue',
        'imagePath': 'https://cdn.example/food.jpg',
        'category': 'food',
      },
    }, currentUserId: 'user-1');

    expect(result.post.id, 'post-1');
    expect(result.post.author.name, 'Lan Nguyen');
    expect(result.post.author.handle, '@lan');
    expect(result.post.author.isVerified, isTrue);
    expect(result.post.author.isFollowing, isFalse);
    expect(result.post.imageUrls, <String>[
      'https://cdn.example/one.jpg',
      'https://cdn.example/two.jpg',
    ]);
    expect(result.post.likes, 8);
    expect(result.post.comments, 3);
    expect(result.post.isLiked, isTrue);
    expect(result.post.isBookmarked, isTrue);
    expect(result.post.showFollowButton, isTrue);
    expect(result.post.sharedItem?.category, DetailCategory.food);
    expect(result.profile.followersCount, 12);
    expect(result.profile.followingCount, 4);
    expect(result.isReported, isTrue);
  });

  test('maps a comment row with author and current-user like state', () {
    final result = mapper.mapCommentRow(<String, dynamic>{
      'id_comment': 'comment-1',
      'id_author_user': 'user-3',
      'content': 'Useful answer',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'author_name': 'Minh',
      'author_username': 'minh',
      'author_avatar': '',
      'author_role': 'user',
      'like_count': '5',
      'is_liked': true,
    });

    expect(result.id, 'comment-1');
    expect(result.author.id, 'user-3');
    expect(result.author.handle, '@minh');
    expect(result.content, 'Useful answer');
    expect(result.likes, 5);
    expect(result.isLiked, isTrue);
  });
}
