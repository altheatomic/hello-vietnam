import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

void main() {
  test(
    'copyWith preserves explore tracking fields when updating unrelated data',
    () {
      const ItemDetailRequest request = ItemDetailRequest(
        id: 'activity-1',
        name: 'Lantern Boat Ride',
        category: DetailCategory.activities,
        trackExploreBehavior: true,
        exploreProvinceId: 'province-48',
      );

      final ItemDetailRequest updated = request.copyWith(name: 'Sunset Cruise');

      expect(updated.name, 'Sunset Cruise');
      expect(updated.trackExploreBehavior, isTrue);
      expect(updated.exploreProvinceId, 'province-48');
    },
  );
}
