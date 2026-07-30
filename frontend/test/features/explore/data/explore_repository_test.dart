import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ExploreRepository.clearProvinceCache();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  test('loads translated province names once per app language and searches locally', () async {
    int fetchCount = 0;
    String? capturedLanguage;
    final ExploreRepository repository = ExploreRepository(
      provincesFetcher: ({String? language}) async {
        fetchCount += 1;
        capturedLanguage = language;
        return <ExploreProvince>[
          const ExploreProvince(id: '1', name: 'Côn Đảo'),
          const ExploreProvince(id: '2', name: 'Đà Nẵng'),
          const ExploreProvince(id: '3', name: 'Hà Nội'),
        ];
      },
    );

    final List<ExploreProvince> first = await repository.searchProvinces('con');
    final List<ExploreProvince> second = await repository.searchProvinces('dao');

    expect(capturedLanguage, 'en');
    expect(fetchCount, 1);
    expect(first.single.name, 'Côn Đảo');
    expect(second.single.id, '1');
  });

  group('ExploreRepository cache', () {
    test('caches sections and can load them back from local storage', () async {
      int fetchCount = 0;
      String? capturedLanguage;
      final ExploreRepository repository = ExploreRepository(
        sectionsFetcher:
            ({
              ExploreProvince? province,
              required int limitPerCategory,
              String? language,
            }) async {
              fetchCount += 1;
              capturedLanguage = language;
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
      expect(capturedLanguage, 'en');
      expect(fresh.province?.name, 'Da Nang');
      expect(cached, isNotNull);
      expect(cached?.province?.id, 'province-1');
      expect(cached?.province?.area, 'Central');
      expect(cached?.categories.first.id, 'activities');
      expect(cached?.categories.first.items.single.name, 'Dragon Bridge Walk');
      expect(cached?.categories.first.items.single.provinceName, 'Da Nang');
    });

    test('returns null when there is no cached sections payload', () async {
      final ExploreRepository repository = ExploreRepository(
        sectionsFetcher:
            ({
              ExploreProvince? province,
              required int limitPerCategory,
              String? language,
            }) async => <String, dynamic>{},
      );

      final ExploreSectionsData? cached = await repository.loadCachedSections(
        province: const ExploreProvince(id: 'province-miss', name: 'Hue'),
      );

      expect(cached, isNull);
    });

    test('separates cached sections by current app language', () async {
      final ExploreRepository repository = ExploreRepository(
        sectionsFetcher:
            ({
              ExploreProvince? province,
              required int limitPerCategory,
              String? language,
            }) async => <String, dynamic>{
              'province': <String, dynamic>{
                'id': 'province-1',
                'name': 'Da Nang',
              },
              'sections': <String, dynamic>{
                'activities': <String, dynamic>{
                  'items': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'activity-1',
                      'name': language == 'vi'
                          ? 'Cau Rong'
                          : 'Dragon Bridge Walk',
                      'imagePath': 'assets/images/explore/sample.jpg',
                      'category': 'activities',
                      'provinceId': 'province-1',
                      'provinceName': 'Da Nang',
                    },
                  ],
                },
                'culture': <String, dynamic>{'items': <Object?>[]},
                'food': <String, dynamic>{'items': <Object?>[]},
                'local_products': <String, dynamic>{'items': <Object?>[]},
              },
            },
      );

      final ExploreProvince province = const ExploreProvince(
        id: 'province-1',
        name: 'Da Nang',
      );

      await repository.loadSections(province: province);
      await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);

      final ExploreSectionsData? cached = await repository.loadCachedSections(
        province: province,
      );

      expect(cached, isNull);
    });
  });

  group('ExploreRepository language forwarding', () {
    test('passes current app language to category item fetcher', () async {
      await AppLanguageController.instance.setLanguage(AppLanguage.english);
      String? capturedLanguage;

      final ExploreRepository repository = ExploreRepository(
        sectionsFetcher:
            ({
              ExploreProvince? province,
              required int limitPerCategory,
              String? language,
            }) async => <String, dynamic>{},
        categoryItemsFetcher:
            ({
              required DetailCategory category,
              ExploreProvince? province,
              required int limit,
              required int offset,
              String? language,
            }) async {
              capturedLanguage = language;
              return <ExploreItem>[
                const ExploreItem(
                  id: 'activity-1',
                  name: 'Dragon Bridge Walk',
                  imagePath: 'assets/images/explore/sample.jpg',
                  category: DetailCategory.activities,
                ),
              ];
            },
      );

      final List<ExploreItem> items = await repository.loadCategoryItems(
        DetailCategory.activities,
        province: const ExploreProvince(id: 'province-1', name: 'Da Nang'),
      );

      expect(capturedLanguage, 'en');
      expect(items.single.name, 'Dragon Bridge Walk');
    });

    test('passes category paging payload to shared function client', () async {
      Object? capturedBody;

      final ExploreRepository repository = ExploreRepository(
        languageCodeProvider: () => 'en',
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                expect(functionName, 'explore');
                capturedBody = body;
                return <String, dynamic>{
                  'items': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'activity-1',
                      'name': 'Dragon Bridge Walk',
                      'imagePath': 'assets/images/explore/sample.jpg',
                      'category': 'activities',
                    },
                  ],
                };
              },
        ),
      );

      final List<ExploreItem> items = await repository.loadCategoryItems(
        DetailCategory.activities,
        province: const ExploreProvince(id: 'province-1', name: 'Da Nang'),
        limit: 12,
        offset: 24,
      );

      expect(capturedBody, <String, Object?>{
        'action': 'getExploreCategoryItems',
        'category': 'activities',
        'provinceId': 'province-1',
        'limit': 12,
        'offset': 24,
        'language': 'en',
      });
      expect(items.single.name, 'Dragon Bridge Walk');
    });

    test('returns backend cursor and forwards a search query', () async {
      Object? capturedBody;
      final ExploreRepository repository = ExploreRepository(
        languageCodeProvider: () => 'en',
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                capturedBody = body;
                return <String, dynamic>{
                  'items': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'food-1',
                      'name': 'Bun bo Hue',
                      'imagePath': 'food/bun-bo.jpg',
                      'category': 'food',
                    },
                  ],
                  'nextOffset': 36,
                  'emptyMessage': null,
                };
              },
        ),
      );

      final ExploreCategoryPageData page = await repository.loadCategoryPage(
        DetailCategory.food,
        limit: 12,
        offset: 24,
        query: 'bun bo',
      );

      expect(capturedBody, <String, Object?>{
        'action': 'getExploreCategoryItems',
        'category': 'food',
        'provinceId': null,
        'limit': 12,
        'offset': 24,
        'language': 'en',
        'query': 'bun bo',
      });
      expect(page.nextOffset, 36);
      expect(page.hasMore, isTrue);
      expect(page.items.single.id, 'food-1');
    });
  });
}
