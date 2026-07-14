enum ReviewContentType {
  activity,
  culture,
  food,
  localProduct,
  place,
  province,
  oldProvince;

  String get apiValue => switch (this) {
    ReviewContentType.activity => 'activity',
    ReviewContentType.culture => 'culture',
    ReviewContentType.food => 'food',
    ReviewContentType.localProduct => 'local_product',
    ReviewContentType.place => 'place',
    ReviewContentType.province => 'province',
    ReviewContentType.oldProvince => 'old_province',
  };
}

class RatingSummary {
  const RatingSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.rating1Count,
    required this.rating2Count,
    required this.rating3Count,
    required this.rating4Count,
    required this.rating5Count,
    this.lastReviewedAt,
  });

  final double averageRating;
  final int reviewCount;
  final int rating1Count;
  final int rating2Count;
  final int rating3Count;
  final int rating4Count;
  final int rating5Count;
  final String? lastReviewedAt;

  int countForStar(int star) => switch (star) {
    1 => rating1Count,
    2 => rating2Count,
    3 => rating3Count,
    4 => rating4Count,
    5 => rating5Count,
    _ => 0,
  };

  int get totalStarCount =>
      rating1Count + rating2Count + rating3Count + rating4Count + rating5Count;

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      averageRating: _doubleValue(json['average_rating']),
      reviewCount: _intValue(json['review_count']),
      rating1Count: _intValue(json['rating_1_count']),
      rating2Count: _intValue(json['rating_2_count']),
      rating3Count: _intValue(json['rating_3_count']),
      rating4Count: _intValue(json['rating_4_count']),
      rating5Count: _intValue(json['rating_5_count']),
      lastReviewedAt: _stringValue(json['last_reviewed_at']),
    );
  }
}

class ReviewEntry {
  const ReviewEntry({
    required this.id,
    required this.rating,
    required this.comment,
    this.userName,
    this.status,
    this.moderationResult,
    this.createdAt,
    this.updatedAt,
    this.updatedAtLabel,
  });

  final String id;
  final int rating;
  final String comment;
  final String? userName;
  final String? status;
  final String? moderationResult;
  final String? createdAt;
  final String? updatedAt;
  final String? updatedAtLabel;

  factory ReviewEntry.fromJson(Map<String, dynamic> json) {
    return ReviewEntry(
      id: _stringValue(json['id']) ?? '',
      rating: _intValue(json['rating']),
      comment: _stringValue(json['comment']) ?? '',
      userName: _stringValue(json['userName'] ?? json['user_name']),
      status: _stringValue(json['status']),
      moderationResult: _stringValue(
        json['moderationResult'] ?? json['moderation_result'],
      ),
      createdAt: _stringValue(json['createdAt'] ?? json['created_at']),
      updatedAt: _stringValue(json['updatedAt'] ?? json['updated_at']),
      updatedAtLabel: _stringValue(json['updatedAtLabel']),
    );
  }
}

class ReviewListPage {
  const ReviewListPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });

  final List<ReviewEntry> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;

  factory ReviewListPage.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    final List<ReviewEntry> items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> item) => ReviewEntry.fromJson(
                  item.map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
        : const <ReviewEntry>[];

    return ReviewListPage(
      items: items,
      page: _intValue(json['page']),
      pageSize: _intValue(json['pageSize']),
      totalCount: _intValue(json['totalCount']),
      hasMore: json['hasMore'] == true,
    );
  }
}

class MyReviewState {
  const MyReviewState({required this.review});

  final ReviewEntry? review;

  bool get hasReview => review != null;
}

class UpsertReviewResult {
  const UpsertReviewResult({required this.review, required this.summary});

  final ReviewEntry review;
  final RatingSummary summary;
}

double _doubleValue(Object? value) => value is num ? value.toDouble() : 0.0;

int _intValue(Object? value) => value is num ? value.toInt() : 0;

String? _stringValue(Object? value) {
  if (value is! String) return null;
  return value;
}
