import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/recommend/data/recommend_repository.dart';
import 'package:hellovietnam/features/recommend/presentation/recommended_place_detail_page.dart';

void main() {
  test('prefers detailed copy and falls back to short then fallback', () {
    final ProvinceTopPlace detailed = ProvinceTopPlace(
      idPlace: 'p1',
      name: 'Huong River',
      shortDescription: 'Short copy',
      detailedDescription: 'Long copy',
    );
    expect(recommendedPlaceDescription(detailed, 'Fallback'), 'Long copy');

    final ProvinceTopPlace shortOnly = ProvinceTopPlace(
      idPlace: 'p2',
      name: 'Place',
      shortDescription: 'Short copy',
      detailedDescription: '   ',
    );
    expect(recommendedPlaceDescription(shortOnly, 'Fallback'), 'Short copy');

    final ProvinceTopPlace empty = ProvinceTopPlace(
      idPlace: 'p3',
      name: 'Place',
    );
    expect(recommendedPlaceDescription(empty, 'Fallback'), 'Fallback');
  });
}
