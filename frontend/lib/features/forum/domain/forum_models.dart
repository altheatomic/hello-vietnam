class ForumAuthor {
  const ForumAuthor({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    this.isVerified = false,
    this.isFollowing = false,
  });

  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final bool isVerified;
  final bool isFollowing;

  ForumAuthor copyWith({
    String? id,
    String? name,
    String? handle,
    String? avatarUrl,
    bool? isVerified,
    bool? isFollowing,
  }) {
    return ForumAuthor(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class ForumUserProfile {
  const ForumUserProfile({
    required this.author,
    required this.followersCount,
    required this.followingCount,
    this.isCurrentUser = false,
  });

  final ForumAuthor author;
  final int followersCount;
  final int followingCount;
  final bool isCurrentUser;

  ForumUserProfile copyWith({
    ForumAuthor? author,
    int? followersCount,
    int? followingCount,
    bool? isCurrentUser,
  }) {
    return ForumUserProfile(
      author: author ?? this.author,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}

class ForumPost {
  const ForumPost({
    required this.id,
    required this.author,
    required this.content,
    required this.imageUrls,
    required this.timeAgo,
    required this.likes,
    required this.comments,
    this.isLiked = false,
    this.isBookmarked = false,
    this.showFollowButton = false,
    this.sharedItem,
  });

  final String id;
  final ForumAuthor author;
  final String content;
  final List<String> imageUrls;
  final String timeAgo;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isBookmarked;
  final bool showFollowButton;
  final Map<String, dynamic>? sharedItem;

  bool get hasTripPlan =>
      sharedItem != null && sharedItem!['type'] == 'trip_plan';

  String? get sharedPlanId => sharedItem?['plan_id'] as String?;

  ForumPost copyWith({
    String? id,
    ForumAuthor? author,
    String? content,
    List<String>? imageUrls,
    String? timeAgo,
    int? likes,
    int? comments,
    bool? isLiked,
    bool? isBookmarked,
    bool? showFollowButton,
    Map<String, dynamic>? sharedItem,
  }) {
    return ForumPost(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      timeAgo: timeAgo ?? this.timeAgo,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      showFollowButton: showFollowButton ?? this.showFollowButton,
      sharedItem: sharedItem ?? this.sharedItem,
    );
  }
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.author,
    required this.content,
    required this.timeAgo,
    required this.likes,
    this.isLiked = false,
  });

  final String id;
  final ForumAuthor author;
  final String content;
  final String timeAgo;
  final int likes;
  final bool isLiked;

  ForumComment copyWith({
    String? id,
    ForumAuthor? author,
    String? content,
    String? timeAgo,
    int? likes,
    bool? isLiked,
  }) {
    return ForumComment(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      timeAgo: timeAgo ?? this.timeAgo,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class ForumNotificationItem {
  const ForumNotificationItem({
    required this.id,
    required this.actor,
    required this.message,
    required this.timeAgo,
    this.postId,
  });

  final String id;
  final ForumAuthor actor;
  final String message;
  final String timeAgo;
  final String? postId;
}
