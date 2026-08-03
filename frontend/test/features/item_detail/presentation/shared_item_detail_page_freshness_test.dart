import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('shows a stale freshness warning below the detail header', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SharedItemDetailPage(
          detail: ItemDetail(
            id: '10000000-0000-4000-8000-000000000001',
            name: 'Cafe Example',
            category: DetailCategory.activities,
            images: const <String>[],
            rating: 0,
            reviewCount: 0,
            ratingLabel: '',
            description: 'Description',
            whatToExpect: '',
            freshnessInfo: const ContentFreshnessInfo(
              status: ContentFreshnessStatus.stale,
            ),
          ),
          showReviews: false,
          showWhatToExpect: false,
          showTrailingGallery: false,
          showShareAction: false,
        ),
      ),
    );

    expect(
      find.text('Information has not been verified recently'),
      findsOneWidget,
    );
  });

  testWidgets('uses an explicit place report target for reused layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SharedItemDetailPage(
          detail: ItemDetail(
            id: '10000000-0000-4000-8000-000000000001',
            name: 'Place Example',
            category: DetailCategory.activities,
            images: const <String>[],
            rating: 0,
            reviewCount: 0,
            ratingLabel: '',
            description: '',
            whatToExpect: '',
          ),
          reportContentType: FreshnessContentType.place,
          showReviews: false,
          showWhatToExpect: false,
          showTrailingGallery: false,
          showShareAction: false,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('freshness-report:place')),
      findsOneWidget,
    );
  });
}
