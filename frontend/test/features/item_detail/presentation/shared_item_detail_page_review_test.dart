import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/reviews/data/review_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('shared item detail page renders the live review section', (
    WidgetTester tester,
  ) async {
    final ReviewRepository repository = ReviewRepository(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () => 'token',
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              final Map<String, Object?> payload =
                  (body as Map<Object?, Object?>).map(
                    (Object? key, Object? value) =>
                        MapEntry(key.toString(), value),
                  );
              switch (payload['action']) {
                case 'getReviewSummary':
                  return <String, Object?>{
                    'average_rating': 4.8,
                    'review_count': 12,
                    'rating_1_count': 0,
                    'rating_2_count': 0,
                    'rating_3_count': 1,
                    'rating_4_count': 2,
                    'rating_5_count': 9,
                  };
                case 'getReviews':
                  return <String, Object?>{
                    'items': <Map<String, Object?>>[
                      <String, Object?>{
                        'id': 'review-1',
                        'user_name': 'Lan',
                        'rating': 5,
                        'comment': 'Loved the broth and the local atmosphere.',
                        'updated_at': '2026-07-12T10:00:00Z',
                      },
                    ],
                    'page': 1,
                    'pageSize': 10,
                    'totalCount': 1,
                    'hasMore': false,
                  };
                case 'getMyReview':
                  return <String, Object?>{};
              }
              return <String, Object?>{};
            },
      ),
    );

    const ItemDetail detail = ItemDetail(
      id: 'hf2',
      reviewContentId: '55555555-5555-4555-8555-555555555555',
      name: 'Bun Bo Hue',
      category: DetailCategory.food,
      images: <String>[],
      rating: 4.7,
      isFavorite: false,
      reviewCount: 7,
      ratingLabel: 'Fantastic',
      description: 'A classic Hue noodle dish.',
      whatToExpect: 'Expect a rich broth and plenty of herbs.',
      reviews: <ItemReview>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SharedItemDetailPage(
          detail: detail,
          reviewRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reviews'), findsWidgets);
    expect(find.text('Write a review'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('review-summary-average')),
      findsOneWidget,
    );
    expect(
      find.text('Loved the broth and the local atmosphere.'),
      findsOneWidget,
    );
  });
}
