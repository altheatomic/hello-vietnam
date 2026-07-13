import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';

class ReviewRepository {
  ReviewRepository({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient ?? SupabaseFunctionClient();

  static final ReviewRepository instance = ReviewRepository();

  final SupabaseFunctionClient _functionClient;

  Future<RatingSummary> loadSummary({
    required ReviewContentType contentType,
    required String contentId,
  }) async {
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      'reviews',
      body: <String, Object?>{
        'action': 'getReviewSummary',
        'contentType': contentType.apiValue,
        'contentId': contentId,
      },
    );
    return RatingSummary.fromJson(data);
  }

  Future<ReviewListPage> loadReviews({
    required ReviewContentType contentType,
    required String contentId,
    required int page,
    int pageSize = 10,
    int? ratingFilter,
  }) async {
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      'reviews',
      body: <String, Object?>{
        'action': 'getReviews',
        'contentType': contentType.apiValue,
        'contentId': contentId,
        'page': page,
        'pageSize': pageSize,
        'ratingFilter':? ratingFilter,
        'sort': 'newest',
      },
    );
    return ReviewListPage.fromJson(data);
  }

  Future<MyReviewState> loadMyReview({
    required ReviewContentType contentType,
    required String contentId,
  }) async {
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      'reviews',
      requireAuth: true,
      body: <String, Object?>{
        'action': 'getMyReview',
        'contentType': contentType.apiValue,
        'contentId': contentId,
      },
    );
    final Map<String, dynamic>? reviewJson = _reviewMap(data);
    return MyReviewState(
      review: reviewJson == null ? null : ReviewEntry.fromJson(reviewJson),
    );
  }

  Future<UpsertReviewResult> upsertReview({
    required ReviewContentType contentType,
    required String contentId,
    required int rating,
    required String comment,
  }) async {
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      'reviews',
      requireAuth: true,
      body: <String, Object?>{
        'action': 'upsertReview',
        'contentType': contentType.apiValue,
        'contentId': contentId,
        'rating': rating,
        'comment': comment,
      },
    );
    final Map<String, dynamic> review = _requiredMap(data['review']);
    final Map<String, dynamic> summary = _requiredMap(data['summary']);
    return UpsertReviewResult(
      review: ReviewEntry.fromJson(review),
      summary: RatingSummary.fromJson(summary),
    );
  }

  Map<String, dynamic>? _reviewMap(Map<String, dynamic> data) {
    final Object? nested = data['review'];
    if (nested is Map) return _map(nested);
    if (data['id'] != null) return data;
    return null;
  }

  Map<String, dynamic> _requiredMap(Object? value) {
    if (value is Map) return _map(value);
    throw const FormatException('Invalid review response.');
  }

  Map<String, dynamic> _map(Map<dynamic, dynamic> value) {
    return value.map(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item),
    );
  }
}
