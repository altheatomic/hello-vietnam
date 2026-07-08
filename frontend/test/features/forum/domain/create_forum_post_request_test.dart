import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  group('SharedExploreItem', () {
    test('serializes and maps back to an item detail request', () {
      const SharedExploreItem item = SharedExploreItem(
        contentType: 'food',
        contentId: 'food-1',
        provinceId: 'province-1',
        title: 'Bun cha',
        imagePath: 'assets/images/explore/sample.jpg',
        category: DetailCategory.food,
        subtitle: 'Local specialty',
        provinceName: 'Ha Noi',
      );

      final SharedExploreItem decoded = SharedExploreItem.fromJson(item.toJson());
      final detailRequest = decoded.toItemDetailRequest();

      expect(decoded.contentType, 'food');
      expect(decoded.contentId, 'food-1');
      expect(decoded.provinceName, 'Ha Noi');
      expect(decoded.subtitle, 'Local specialty');
      expect(detailRequest.id, 'food-1');
      expect(detailRequest.name, 'Bun cha');
      expect(detailRequest.category, DetailCategory.food);
      expect(detailRequest.exploreProvinceId, 'province-1');
      expect(
        detailRequest.fallbackImages,
        <String>['assets/images/explore/sample.jpg'],
      );
    });
  });
}
