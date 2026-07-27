import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/reviews/data/review_repository.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';

void main() {
  setUp(ReviewRepository.clearCache);

  test('caches the first review summary for the same content', () async {
    int callCount = 0;
    final ReviewRepository repository = ReviewRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              callCount++;
              return <String, Object?>{
                'average_rating': 5.0,
                'review_count': 1,
                'rating_1_count': 0,
                'rating_2_count': 0,
                'rating_3_count': 0,
                'rating_4_count': 0,
                'rating_5_count': 1,
              };
            },
      ),
    );

    await repository.loadSummary(
      contentType: ReviewContentType.activity,
      contentId: 'activity-1',
    );
    final RatingSummary second = await repository.loadSummary(
      contentType: ReviewContentType.activity,
      contentId: 'activity-1',
    );

    expect(callCount, 1);
    expect(second.reviewCount, 1);
  });

  test('loadReviews sends page, pageSize, and optional rating filter', () async {
    Object? capturedBody;

    final ReviewRepository repository = ReviewRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              expect(functionName, 'reviews');
              capturedBody = body;
              return <String, Object?>{
                'items': <Map<String, Object?>>[],
                'page': 1,
                'pageSize': 10,
                'totalCount': 0,
                'hasMore': false,
              };
            },
      ),
    );

    await repository.loadReviews(
      contentType: ReviewContentType.food,
      contentId: 'food-1',
      page: 1,
      pageSize: 10,
      ratingFilter: 5,
    );

    expect(capturedBody, <String, Object?>{
      'action': 'getReviews',
      'contentType': 'food',
      'contentId': 'food-1',
      'page': 1,
      'pageSize': 10,
      'ratingFilter': 5,
      'sort': 'newest',
    });
  });

  test('loadReviews parses pagination and review entries', () async {
    final ReviewRepository repository = _repositoryReturning(<String, Object?>{
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'review-1',
          'rating': 5,
          'comment': 'Excellent pho',
          'status': 'published',
          'moderationResult': 'clean',
          'createdAt': '2026-07-11T10:00:00Z',
          'updatedAt': '2026-07-11T11:00:00Z',
        },
      ],
      'page': 2,
      'pageSize': 10,
      'totalCount': 11,
      'hasMore': true,
    });

    final ReviewListPage result = await repository.loadReviews(
      contentType: ReviewContentType.food,
      contentId: 'food-1',
      page: 2,
    );

    expect(result.page, 2);
    expect(result.pageSize, 10);
    expect(result.totalCount, 11);
    expect(result.hasMore, isTrue);
    expect(result.items.single.comment, 'Excellent pho');
    expect(result.items.single.updatedAt, '2026-07-11T11:00:00Z');
  });

  test('loadSummary sends content reference and parses rating counts', () async {
    Object? capturedBody;
    final ReviewRepository repository = ReviewRepository(
      functionClient: SupabaseFunctionClient(
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              capturedBody = body;
              return <String, Object?>{
                'average_rating': 4.25,
                'review_count': 4,
                'rating_1_count': 0,
                'rating_2_count': 0,
                'rating_3_count': 1,
                'rating_4_count': 1,
                'rating_5_count': 2,
              };
            },
      ),
    );

    final RatingSummary result = await repository.loadSummary(
      contentType: ReviewContentType.localProduct,
      contentId: 'product-1',
    );

    expect(capturedBody, <String, Object?>{
      'action': 'getReviewSummary',
      'contentType': 'local_product',
      'contentId': 'product-1',
    });
    expect(result.averageRating, 4.25);
    expect(result.reviewCount, 4);
    expect(result.rating5Count, 2);
  });

  test('loadMyReview requires auth and parses an existing review', () async {
    Object? capturedBody;
    bool requireAuthObserved = false;
    final ReviewRepository repository = ReviewRepository(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () => 'token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              capturedBody = body;
              requireAuthObserved = headers?['Authorization'] == 'Bearer token';
              return <String, Object?>{
                'id': 'review-1',
                'rating': 4,
                'comment': 'Nice place',
                'status': 'published',
                'moderationResult': 'clean',
                'createdAt': '2026-07-10T10:00:00Z',
                'updatedAt': '2026-07-11T10:00:00Z',
              };
            },
      ),
    );

    final MyReviewState result = await repository.loadMyReview(
      contentType: ReviewContentType.place,
      contentId: 'place-1',
    );

    expect(requireAuthObserved, isTrue);
    expect(capturedBody, <String, Object?>{
      'action': 'getMyReview',
      'contentType': 'place',
      'contentId': 'place-1',
    });
    expect(result.review?.id, 'review-1');
    expect(result.hasReview, isTrue);
  });

  test('upsertReview forwards review fields and parses refreshed result', () async {
    Object? capturedBody;
    final ReviewRepository repository = ReviewRepository(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () => 'token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              capturedBody = body;
              return <String, Object?>{
                'review': <String, Object?>{
                  'id': 'review-2',
                  'rating': 5,
                  'comment': 'Wonderful',
                  'status': 'published',
                  'moderationResult': 'clean',
                  'createdAt': '2026-07-12T10:00:00Z',
                  'updatedAt': '2026-07-12T10:00:00Z',
                },
                'summary': <String, Object?>{
                  'average_rating': 5.0,
                  'review_count': 1,
                  'rating_1_count': 0,
                  'rating_2_count': 0,
                  'rating_3_count': 0,
                  'rating_4_count': 0,
                  'rating_5_count': 1,
                },
              };
            },
      ),
    );

    final UpsertReviewResult result = await repository.upsertReview(
      contentType: ReviewContentType.activity,
      contentId: 'activity-1',
      rating: 5,
      comment: 'Wonderful',
    );

    expect(capturedBody, <String, Object?>{
      'action': 'upsertReview',
      'contentType': 'activity',
      'contentId': 'activity-1',
      'rating': 5,
      'comment': 'Wonderful',
    });
    expect(result.review.id, 'review-2');
    expect(result.summary.reviewCount, 1);
  });
}

ReviewRepository _repositoryReturning(Map<String, Object?> response) {
  return ReviewRepository(
    functionClient: SupabaseFunctionClient(
      invoker:
          (String functionName, {Map<String, String>? headers, Object? body}) async =>
              response,
    ),
  );
}
