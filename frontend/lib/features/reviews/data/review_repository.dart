import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';

class ReviewRepository {
  ReviewRepository({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient ?? SupabaseFunctionClient();

  static final ReviewRepository instance = ReviewRepository();

  static const Duration _cacheTtl = Duration(minutes: 15);
  static final Map<String, _CachedRatingSummary> _summaryCache =
      <String, _CachedRatingSummary>{};
  static final Map<String, _CachedReviewListPage> _firstPageCache =
      <String, _CachedReviewListPage>{};

  final SupabaseFunctionClient _functionClient;

  static void clearCache() {
    _summaryCache.clear();
    _firstPageCache.clear();
  }

  Future<RatingSummary> loadSummary({
    required ReviewContentType contentType,
    required String contentId,
  }) async {
    final String key = _contentKey(contentType, contentId);
    final _CachedRatingSummary? cached = _summaryCache[key];
    if (cached != null && cached.isFresh) return cached.value;

    final Map<String, dynamic> data = await _functionClient.invokeJson(
      'reviews',
      body: <String, Object?>{
        'action': 'getReviewSummary',
        'contentType': contentType.apiValue,
        'contentId': contentId,
      },
    );
    final RatingSummary value = RatingSummary.fromJson(data);
    _summaryCache[key] = _CachedRatingSummary(value);
    return value;
  }

  Future<ReviewListPage> loadReviews({
    required ReviewContentType contentType,
    required String contentId,
    required int page,
    int pageSize = 10,
    int? ratingFilter,
  }) async {
    final bool cacheable = page == 1 && ratingFilter == null;
    final String key = _contentKey(contentType, contentId);
    final String pageKey = '$key:$pageSize';
    final _CachedReviewListPage? cached =
        cacheable ? _firstPageCache[pageKey] : null;
    if (cached != null && cached.isFresh) return cached.value;

    final Map<String, dynamic> data = await _functionClient.invokeJson(
      'reviews',
      body: <String, Object?>{
        'action': 'getReviews',
        'contentType': contentType.apiValue,
        'contentId': contentId,
        'page': page,
        'pageSize': pageSize,
        'ratingFilter': ratingFilter,
        'sort': 'newest',
      },
    );
    final ReviewListPage value = ReviewListPage.fromJson(data);
    if (cacheable) _firstPageCache[pageKey] = _CachedReviewListPage(value);
    return value;
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
    final UpsertReviewResult result = UpsertReviewResult(
      review: ReviewEntry.fromJson(review),
      summary: RatingSummary.fromJson(summary),
    );
    final String key = _contentKey(contentType, contentId);
    _summaryCache.remove(key);
    _firstPageCache.removeWhere(
      (String cacheKey, _CachedReviewListPage value) =>
          cacheKey.startsWith('$key:'),
    );
    return result;
  }

  String _contentKey(ReviewContentType contentType, String contentId) {
    return '${contentType.apiValue}:$contentId';
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

class _CachedRatingSummary {
  _CachedRatingSummary(this.value) : cachedAt = DateTime.now();

  final RatingSummary value;
  final DateTime cachedAt;

  bool get isFresh =>
      DateTime.now().difference(cachedAt) < ReviewRepository._cacheTtl;
}

class _CachedReviewListPage {
  _CachedReviewListPage(this.value) : cachedAt = DateTime.now();

  final ReviewListPage value;
  final DateTime cachedAt;

  bool get isFresh =>
      DateTime.now().difference(cachedAt) < ReviewRepository._cacheTtl;
}
