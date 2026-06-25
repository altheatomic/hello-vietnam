import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ExploreRepository cache', () {
    test('caches sections and can load them back from local storage', () async {
      int fetchCount = 0;
      final ExploreRepository repository = ExploreRepository(
        sectionsFetcher: ({
          ExploreProvince? province,
          required int limitPerCategory,
        }) async {
          fetchCount += 1;
          return <String, dynamic>{
            'province': <String, dynamic>{
              'id': 'province-1',
              'name': 'Da Nang',
              'area': 'Central',
            },
            'sections': <String, dynamic>{
              'activities': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'activity-1',
                    'name': 'Dragon Bridge Walk',
                    'imagePath': 'assets/images/explore/sample.jpg',
                    'category': 'activities',
                    'subtitle': 'Riverfront',
                    'provinceId': 'province-1',
                    'provinceName': 'Da Nang',
                  },
                ],
              },
              'culture': <String, dynamic>{'items': <Object?>[]},
              'food': <String, dynamic>{'items': <Object?>[]},
              'local_products': <String, dynamic>{'items': <Object?>[]},
            },
          };
        },
      );

      final ExploreSectionsData fresh = await repository.loadSections();
      final ExploreSectionsData? cached = await repository.loadCachedSections();

      expect(fetchCount, 1);
      expect(fresh.province?.name, 'Da Nang');
      expect(cached, isNotNull);
      expect(cached?.province?.id, 'province-1');
      expect(cached?.province?.area, 'Central');
      expect(cached?.categories.first.id, 'activities');
      expect(cached?.categories.first.items.single.name, 'Dragon Bridge Walk');
      expect(
        cached?.categories.first.items.single.provinceName,
        'Da Nang',
      );
    });

    test('returns null when there is no cached sections payload', () async {
      final ExploreRepository repository = ExploreRepository(
        sectionsFetcher: ({
          ExploreProvince? province,
          required int limitPerCategory,
        }) async => <String, dynamic>{},
      );

      final ExploreSectionsData? cached = await repository.loadCachedSections(
        province: const ExploreProvince(id: 'province-miss', name: 'Hue'),
      );

      expect(cached, isNull);
    });
  });
}
