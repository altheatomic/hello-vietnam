import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:hellovietnam/features/explore/presentation/explore_page.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
      return;
    } catch (_) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ExplorePage cache-first', () {
    testWidgets('renders cached sections immediately before refresh completes', (
      WidgetTester tester,
    ) async {
      final Completer<ExploreSectionsData> refreshCompleter =
          Completer<ExploreSectionsData>();
      final _FakeExploreRepository repository = _FakeExploreRepository(
        cachedSections: _sectionsData('Cached Activity'),
        freshSectionsFuture: refreshCompleter.future,
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();

      expect(find.text('Cached Activity'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      refreshCompleter.complete(_sectionsData('Fresh Activity'));
      await tester.pump();

      expect(find.text('Fresh Activity'), findsOneWidget);
    });

    testWidgets('keeps cached content visible when background refresh fails', (
      WidgetTester tester,
    ) async {
      final _FakeExploreRepository repository = _FakeExploreRepository(
        cachedSections: _sectionsData('Cached Activity'),
        refreshError: StateError('refresh failed'),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump();

      expect(find.text('Cached Activity'), findsOneWidget);
      expect(find.text('Unable to load Explore right now.'), findsNothing);
    });
  });
}

Widget _buildTestApp(ExploreRepository repository) {
  return AppLanguageScope(
    controller: AppLanguageController.instance,
    child: MaterialApp(home: ExplorePage(repository: repository)),
  );
}

ExploreSectionsData _sectionsData(String itemName) {
  return ExploreSectionsData(
    province: const ExploreProvince(id: 'province-1', name: 'Da Nang'),
    categories: <ExploreCategory>[
      ExploreCategory(
        id: 'activities',
        title: 'Activities',
        description: 'Hands-on experiences and cultural activities',
        items: <ExploreItem>[
          ExploreItem(
            id: 'item-1',
            name: itemName,
            imagePath: 'assets/images/explore/sample.jpg',
            category: DetailCategory.activities,
            provinceId: 'province-1',
            provinceName: 'Da Nang',
          ),
        ],
      ),
      const ExploreCategory(
        id: 'culture',
        title: 'Culture',
        description: 'Traditional customs, heritage, and cultural practices',
        items: <ExploreItem>[],
      ),
      const ExploreCategory(
        id: 'food',
        title: 'Food',
        description: 'Local dishes and culinary specialties from different regions',
        items: <ExploreItem>[],
      ),
      const ExploreCategory(
        id: 'local_products',
        title: 'Local Products',
        description: 'Traditional goods and handcrafted regional products',
        items: <ExploreItem>[],
      ),
    ],
  );
}

class _FakeExploreRepository extends ExploreRepository {
  _FakeExploreRepository({
    this.cachedSections,
    this.freshSectionsFuture,
    this.refreshError,
  });

  final ExploreSectionsData? cachedSections;
  final Future<ExploreSectionsData>? freshSectionsFuture;
  final Object? refreshError;

  @override
  Future<ExploreSectionsData?> loadCachedSections({
    ExploreProvince? province,
    int limitPerCategory = 4,
  }) async {
    return cachedSections;
  }

  @override
  Future<ExploreSectionsData> loadSections({
    ExploreProvince? province,
    int limitPerCategory = 4,
  }) async {
    if (refreshError != null) {
      throw refreshError!;
    }
    return freshSectionsFuture ?? cachedSections!;
  }
}
