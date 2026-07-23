import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/data/item_detail_repository.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/reviews/data/review_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('shared item detail page renders the live review section', (
    WidgetTester tester,
  ) async {
    final ReviewRepository repository = _buildReviewRepository();

    const ItemDetail detail = ItemDetail(
      id: 'hf2',
      reviewContentId: '55555555-5555-4555-8555-555555555555',
      name: 'Bun Bo Hue',
      category: DetailCategory.food,
      images: <String>[''],
      rating: 4.7,
      isFavorite: false,
      reviewCount: 7,
      ratingLabel: 'Fantastic',
      description: 'A classic Hue noodle dish.',
      whatToExpect: 'Expect a rich broth and plenty of herbs.',
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

    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('review-summary-average')),
      findsOneWidget,
    );
    expect(
      find.text('Loved the broth and the local atmosphere.'),
      findsOneWidget,
    );
    expect(find.text('4.7'), findsNothing);
    expect(find.text('4.8'), findsWidgets);
  });

  testWidgets('shared detail labels are fully localized in Vietnamese', (
    WidgetTester tester,
  ) async {
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
    addTearDown(
      () => AppLanguageController.instance.setLanguage(AppLanguage.english),
    );

    const ItemDetail detail = ItemDetail(
      id: 'hf2',
      reviewContentId: '55555555-5555-4555-8555-555555555555',
      name: 'Bún bò Huế',
      category: DetailCategory.food,
      images: <String>[''],
      rating: 4.7,
      isFavorite: false,
      reviewCount: 7,
      ratingLabel: 'Fantastic',
      description:
          'Đây là phần mô tả rất dài về món ăn, nguồn gốc, hương vị và cách thưởng thức để nội dung chắc chắn vượt quá ba dòng hiển thị ban đầu trên thẻ thông tin chi tiết của ứng dụng.',
      whatToExpect: 'Hương vị đậm đà và nhiều loại rau thơm.',
    );

    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: SharedItemDetailPage(
            detail: detail,
            reviewRepository: _buildReviewRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Khám phá,', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Đánh giá'), findsOneWidget);
    expect(find.text('Trải nghiệm nổi bật'), findsOneWidget);
    expect(find.text('Viết đánh giá'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('5 sao'), findsWidgets);
    expect(find.text('Xem thêm'), findsOneWidget);
    expect(find.text('Reviews'), findsNothing);
    expect(find.text('What to expect'), findsNothing);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('long detail title stays centered with equal side margins', (
    WidgetTester tester,
  ) async {
    const String longTitle =
        'A Very Long Vietnamese Destination Name That Needs Two Lines';
    const ItemDetail detail = ItemDetail(
      id: 'long-title',
      name: longTitle,
      category: DetailCategory.activities,
      images: <String>[''],
      rating: 4.5,
      reviewCount: 0,
      ratingLabel: 'Great',
      description: 'Description',
      whatToExpect: 'What to expect',
    );
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SharedItemDetailPage(
          detail: detail,
          showReviews: false,
          showWhatToExpect: false,
        ),
      ),
    );
    await tester.pump();

    final Finder titleFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is RichText && widget.text.toPlainText().contains(longTitle),
    );
    final RichText title = tester.widget<RichText>(titleFinder);
    final Rect titleRect = tester.getRect(titleFinder);

    expect(title.textAlign, TextAlign.center);
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(titleRect.left, closeTo(320 - titleRect.right, 0.1));
  });

  testWidgets('request-backed detail loads the live backend item', (
    WidgetTester tester,
  ) async {
    final Completer<ItemDetail> completer = Completer<ItemDetail>();
    final _FakeItemDetailRepository repository = _FakeItemDetailRepository(
      completer.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SharedItemDetailPage(
          request: const ItemDetailRequest(
            id: '55555555-5555-4555-8555-555555555555',
            name: 'Fallback item',
            category: DetailCategory.food,
          ),
          itemDetailRepository: repository,
          showReviews: false,
          showWhatToExpect: false,
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    completer.complete(
      const ItemDetail(
        id: '55555555-5555-4555-8555-555555555555',
        name: 'Live Bun Bo Hue',
        category: DetailCategory.food,
        images: <String>[],
        rating: 4.9,
        reviewCount: 20,
        ratingLabel: 'Excellent',
        description: 'Live description from Supabase.',
        whatToExpect: 'Live expectation from Supabase.',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Live Bun Bo Hue', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Live description from Supabase.'), findsOneWidget);
    expect(
      find.textContaining('Fallback item', findRichText: true),
      findsNothing,
    );
  });
}

class _FakeItemDetailRepository extends ItemDetailRepository {
  _FakeItemDetailRepository(this.result);

  final Future<ItemDetail> result;

  @override
  Future<ItemDetail> load(ItemDetailRequest request) => result;
}

ReviewRepository _buildReviewRepository() {
  return ReviewRepository(
    functionClient: SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker:
          (
            String functionName, {
            Map<String, String>? headers,
            Object? body,
          }) async {
            final Map<String, Object?> payload = (body as Map<Object?, Object?>)
                .map(
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
}
