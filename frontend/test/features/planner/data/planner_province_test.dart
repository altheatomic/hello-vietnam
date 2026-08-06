import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/planner_province.dart';

void main() {
  test('maps a cached province R2 key to an absolute URL', () {
    final PlannerProvince province =
        PlannerProvince.fromReferenceRecord(<String, dynamic>{
          'id_province': 'p1',
          'name': 'Ha Tinh',
          'region_code': 'North Central',
          'cover_image': 'province/p1/cover.jpg',
        }, mediaResolver: (String raw) => 'https://media.test/$raw');

    expect(province.coverImage, 'https://media.test/province/p1/cover.jpg');
  });
}
