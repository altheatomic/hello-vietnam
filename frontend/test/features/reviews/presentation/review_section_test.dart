import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';
import 'package:hellovietnam/features/reviews/presentation/review_section.dart';

void main() {
  const RatingSummary summary = RatingSummary(
    averageRating: 4.6,
    reviewCount: 20,
    rating1Count: 1,
    rating2Count: 1,
    rating3Count: 2,
    rating4Count: 6,
    rating5Count: 10,
  );

  testWidgets('review section loads next page once near list end', (
    WidgetTester tester,
  ) async {
    final List<_LoadCall> calls = <_LoadCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReviewSection(
              contentType: ReviewContentType.food,
              contentId: 'food-1',
              itemTitle: 'Pho',
              initialSummary: summary,
              summaryLoader: () async => summary,
              myReviewLoader: () async => const MyReviewState(review: null),
              loader: ({
                required int page,
                required int pageSize,
                int? ratingFilter,
              }) async {
                calls.add(_LoadCall(page: page, ratingFilter: ratingFilter));
                return ReviewListPage(
                  items: List<ReviewEntry>.generate(
                    10,
                    (int index) => ReviewEntry(
                      id: 'review-$page-$index',
                      userName: 'User $index',
                      rating: 5,
                      comment: 'Page $page comment $index',
                      updatedAtLabel: '2026-07-12',
                    ),
                  ),
                  page: page,
                  pageSize: pageSize,
                  totalCount: 20,
                  hasMore: page == 1,
                );
              },
              listHeight: 160,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(calls, <_LoadCall>[const _LoadCall(page: 1)]);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('review-list')));
    await tester.drag(
      find.byKey(const ValueKey<String>('review-list')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(
      calls,
      <_LoadCall>[const _LoadCall(page: 1), const _LoadCall(page: 2)],
    );
  });

  testWidgets('review section resets pagination when the star filter changes', (
    WidgetTester tester,
  ) async {
    final List<_LoadCall> calls = <_LoadCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReviewSection(
              contentType: ReviewContentType.food,
              contentId: 'food-1',
              itemTitle: 'Pho',
              initialSummary: summary,
              summaryLoader: () async => summary,
              myReviewLoader: () async => const MyReviewState(review: null),
              loader: ({
                required int page,
                required int pageSize,
                int? ratingFilter,
              }) async {
                calls.add(_LoadCall(page: page, ratingFilter: ratingFilter));
                final String prefix = ratingFilter == null ? 'all' : 'star-$ratingFilter';
                return ReviewListPage(
                  items: List<ReviewEntry>.generate(
                    10,
                    (int index) => ReviewEntry(
                      id: '$prefix-$page-$index',
                      userName: 'User $index',
                      rating: ratingFilter ?? 4,
                      comment: '$prefix page $page comment $index',
                      updatedAtLabel: '2026-07-12',
                    ),
                  ),
                  page: page,
                  pageSize: pageSize,
                  totalCount: 20,
                  hasMore: page == 1,
                );
              },
              listHeight: 160,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('review-list')));
    await tester.drag(
      find.byKey(const ValueKey<String>('review-list')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('review-filter-5')));
    await tester.pumpAndSettle();

    expect(
      calls,
      <_LoadCall>[
        const _LoadCall(page: 1),
        const _LoadCall(page: 2),
        const _LoadCall(page: 1, ratingFilter: 5),
      ],
    );
    expect(find.text('star-5 page 1 comment 0'), findsOneWidget);
    expect(find.text('all page 2 comment 0'), findsNothing);
  });
}

class _LoadCall {
  const _LoadCall({required this.page, this.ratingFilter});

  final int page;
  final int? ratingFilter;

  @override
  bool operator ==(Object other) {
    return other is _LoadCall &&
        other.page == page &&
        other.ratingFilter == ratingFilter;
  }

  @override
  int get hashCode => Object.hash(page, ratingFilter);
}
