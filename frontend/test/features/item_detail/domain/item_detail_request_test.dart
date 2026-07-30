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

  test('uses the legacy single image as gallery fallback', () {
    const ItemDetail detail = ItemDetail(
      id: 'legacy-detail',
      name: 'Legacy detail',
      category: DetailCategory.activities,
      images: <String>['legacy-cover.jpg'],
      rating: 0,
      reviewCount: 0,
      ratingLabel: '',
      description: '',
      whatToExpect: '',
    );

    expect(detail.effectiveGalleryImages, <String>['legacy-cover.jpg']);
  });

  test('does not reuse an explicit cover as gallery fallback', () {
    const ItemDetail detail = ItemDetail(
      id: 'place-detail',
      name: 'Place detail',
      category: DetailCategory.activities,
      images: <String>['cover.jpg'],
      coverImage: 'cover.jpg',
      rating: 0,
      reviewCount: 0,
      ratingLabel: '',
      description: '',
      whatToExpect: '',
    );

    expect(detail.effectiveGalleryImages, isEmpty);
  });
}
