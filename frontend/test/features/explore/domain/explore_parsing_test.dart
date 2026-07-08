import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  group('parseExploreSearchResultExtra', () {
    test('accepts map payload without throwing', () {
      final ExploreProvince province = parseExploreSearchResultExtra(
        <String, dynamic>{
          'id': 'province-1',
          'name': 'Da Nang',
          'area': 'Central',
        },
      );

      expect(province.id, 'province-1');
      expect(province.name, 'Da Nang');
      expect(province.area, 'Central');
    });

    test('falls back safely for unexpected payload type', () {
      final ExploreProvince province = parseExploreSearchResultExtra(
        <String, dynamic>{'name': <String, dynamic>{'vi': 'Da Nang'}},
      );

      expect(province.id, '');
      expect(province.name, '');
    });
  });

  group('ExploreItem.fromJson', () {
    test('tolerates non-string fields without crashing', () {
      final ExploreItem item = ExploreItem.fromJson(<String, dynamic>{
        'id': 'activity-1',
        'name': 'Dragon Bridge Walk',
        'imagePath': <String, dynamic>{'url': 'broken'},
        'category': 'activities',
        'subtitle': <String, dynamic>{'text': 'Riverfront'},
        'provinceId': 123,
        'provinceName': <String, dynamic>{'en': 'Da Nang'},
      });

      expect(item.id, 'activity-1');
      expect(item.name, 'Dragon Bridge Walk');
      expect(item.imagePath, '');
      expect(item.subtitle, isNull);
      expect(item.provinceId, '123');
      expect(item.provinceName, isNull);
      expect(item.category, DetailCategory.activities);
    });
  });

  group('ExploreProvince.fromJson', () {
    test('tolerates non-string optional fields without crashing', () {
      final ExploreProvince province = ExploreProvince.fromJson(
        <String, dynamic>{
          'id': 'province-1',
          'name': 'Da Nang',
          'area': <String, dynamic>{'en': 'Central'},
          'description': 99,
        },
      );

      expect(province.id, 'province-1');
      expect(province.name, 'Da Nang');
      expect(province.area, isNull);
      expect(province.description, '99');
    });
  });
}
