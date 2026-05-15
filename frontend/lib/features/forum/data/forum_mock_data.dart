import 'package:hellovietnam/features/forum/domain/forum_models.dart';

class ForumMockData {
  ForumMockData._();

  static const String currentUserId = 'cortstllylo';

  static const ForumAuthor cortstllylo = ForumAuthor(
    id: 'cortstllylo',
    name: 'Cortstllylo',
    handle: '@cortstllylo',
    avatarUrl:
        'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?auto=format&fit=crop&w=240&q=80',
    isVerified: true,
  );

  static const ForumAuthor travelvn = ForumAuthor(
    id: 'travelvn',
    name: 'TravelVN',
    handle: '@travelvn',
    avatarUrl:
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=240&q=80',
    isVerified: true,
  );

  static const ForumAuthor foodieExplorer = ForumAuthor(
    id: 'foodieexplorer',
    name: 'FoodieExplorer',
    handle: '@foodieexplorer',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=240&q=80',
    isFollowing: true,
  );

  static const ForumAuthor streetFoodLover = ForumAuthor(
    id: 'streetfoodlover',
    name: 'StreetFoodLover',
    handle: '@streetfoodlover',
    avatarUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=240&q=80',
    isVerified: true,
  );

  static const ForumAuthor vietnamGuide = ForumAuthor(
    id: 'vietnamguide',
    name: 'VietnamGuide',
    handle: '@vietnamguide',
    avatarUrl:
        'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?auto=format&fit=crop&w=240&q=80',
    isVerified: true,
    isFollowing: true,
  );

  static const ForumAuthor foodCritic = ForumAuthor(
    id: 'foodcritic',
    name: 'FoodCritic',
    handle: '@foodcritic',
    avatarUrl:
        'https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=240&q=80',
    isVerified: true,
  );

  static const ForumAuthor localExpert = ForumAuthor(
    id: 'localexpert',
    name: 'LocalExpert',
    handle: '@localexpert',
    avatarUrl:
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=240&q=80',
  );

  static const ForumAuthor travelBlogger = ForumAuthor(
    id: 'travelblogger',
    name: 'TravelBlogger',
    handle: '@travelblogger',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80',
    isVerified: true,
  );

  static const ForumAuthor vnFoodLover = ForumAuthor(
    id: 'vnfoodlover',
    name: 'VNFoodLover',
    handle: '@vnfoodlover',
    avatarUrl:
        'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=crop&w=240&q=80',
  );

  static const Map<String, ForumUserProfile> profilesById =
      <String, ForumUserProfile>{
        'cortstllylo': ForumUserProfile(
          author: cortstllylo,
          followersCount: 1200,
          followingCount: 324,
          isCurrentUser: true,
        ),
        'travelvn': ForumUserProfile(
          author: travelvn,
          followersCount: 1200,
          followingCount: 324,
        ),
        'foodieexplorer': ForumUserProfile(
          author: foodieExplorer,
          followersCount: 860,
          followingCount: 192,
        ),
        'streetfoodlover': ForumUserProfile(
          author: streetFoodLover,
          followersCount: 1580,
          followingCount: 270,
        ),
        'vietnamguide': ForumUserProfile(
          author: vietnamGuide,
          followersCount: 1420,
          followingCount: 401,
        ),
      };

  static const ForumAuthor currentUser = cortstllylo;

  static const List<ForumPost> posts = <ForumPost>[
    ForumPost(
      id: 'post-bun-mam',
      author: cortstllylo,
      content: 'Try this "Bun mam nem" one out! 🍜 Best food in Saigon',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f?auto=format&fit=crop&w=1200&q=80',
      ],
      timeAgo: '2h ago',
      likes: 124,
      comments: 32,
      isBookmarked: true,
    ),
    ForumPost(
      id: 'post-coffee',
      author: travelvn,
      content:
          'Morning vibes with authentic Vietnamese coffee ☕ #SaigonCoffee #TravelVietnam',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80',
      ],
      timeAgo: '4h ago',
      likes: 89,
      comments: 15,
      showFollowButton: true,
    ),
    ForumPost(
      id: 'post-spring-rolls',
      author: foodieExplorer,
      content:
          "Can't get enough of these fresh spring rolls! 🥗 Where's your favorite spot?\n#SaigonFood",
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1515669097368-22e68427d265?auto=format&fit=crop&w=1200&q=80',
      ],
      timeAgo: '6h ago',
      likes: 156,
      comments: 42,
      isBookmarked: true,
      showFollowButton: true,
    ),
    ForumPost(
      id: 'post-banh-mi',
      author: streetFoodLover,
      content:
          'Street food tour in District 1! The banh mi here is absolutely incredible 🥖\n#SaigonFood #StreetFood',
      imageUrls: <String>['assets/images/dishes/banh_mi.jpg'],
      timeAgo: '8h ago',
      likes: 203,
      comments: 58,
      showFollowButton: true,
    ),
    ForumPost(
      id: 'post-night-market',
      author: vietnamGuide,
      content:
          'Night market adventures! Best place to experience local culture 🌃 #SaigonNightLife',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
      ],
      timeAgo: '10h ago',
      likes: 178,
      comments: 35,
      showFollowButton: true,
    ),
  ];

  static const List<String> initialForYouFeed = <String>[
    'post-bun-mam',
    'post-coffee',
    'post-spring-rolls',
    'post-banh-mi',
    'post-night-market',
  ];

  static const List<String> initialFollowingFeed = <String>[
    'post-spring-rolls',
    'post-night-market',
  ];

  static const Map<String, List<ForumComment>>
  commentsByPost = <String, List<ForumComment>>{
    'post-bun-mam': <ForumComment>[
      ForumComment(
        id: 'comment-foodcritic',
        author: foodCritic,
        content: 'Looks amazing! Which district is this? 😍',
        timeAgo: '1h ago',
        likes: 12,
      ),
      ForumComment(
        id: 'comment-localexpert',
        author: localExpert,
        content:
            'Been there last week, totally recommend! The broth is perfect 🔥',
        timeAgo: '45m ago',
        likes: 8,
      ),
      ForumComment(
        id: 'comment-travelblogger',
        author: travelBlogger,
        content: 'Adding this to my must-visit list! Thanks for sharing 🙏',
        timeAgo: '30m ago',
        likes: 5,
      ),
      ForumComment(
        id: 'comment-vnfoodlover',
        author: vnFoodLover,
        content: 'Is this near Ben Thanh Market?',
        timeAgo: '20m ago',
        likes: 3,
      ),
    ],
  };

  static const List<ForumNotificationItem> notifications =
      <ForumNotificationItem>[
        ForumNotificationItem(
          id: 'notif-like',
          actor: travelvn,
          message: 'liked your post',
          timeAgo: '5m ago',
          postId: 'post-bun-mam',
        ),
        ForumNotificationItem(
          id: 'notif-comment',
          actor: foodieExplorer,
          message: 'commented on your post',
          timeAgo: '10m ago',
          postId: 'post-bun-mam',
        ),
        ForumNotificationItem(
          id: 'notif-mention',
          actor: streetFoodLover,
          message: 'mentioned you in a post',
          timeAgo: '15m ago',
          postId: 'post-bun-mam',
        ),
        ForumNotificationItem(
          id: 'notif-follow',
          actor: vietnamGuide,
          message: 'started following you',
          timeAgo: '20m ago',
        ),
        ForumNotificationItem(
          id: 'notif-reply',
          actor: travelvn,
          message: 'replied to your comment',
          timeAgo: '24m ago',
          postId: 'post-bun-mam',
        ),
      ];

  static const List<String> uploadImageOptions = <String>[
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
    'assets/images/dishes/banh_mi.jpg',
  ];
}
