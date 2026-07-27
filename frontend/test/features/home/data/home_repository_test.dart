import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/home/data/home_repository.dart';

void main() {
  test('maps one RPC payload and resolves R2 media keys', () async {
    int? requestedLimit;
    final HomeRepository repository = HomeRepository(
      rpcInvoker: (int limit) async {
        requestedLimit = limit;
        return <String, dynamic>{
          'destinations': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'province-1',
              'name': 'Ha Tinh',
              'category': 'North Central',
              'description': 'Coastal province',
              'image_path': 'provinces/ha-tinh/cover.jpg',
              'rating': 4.75,
              'review_count': 8,
            },
          ],
          'dishes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'food-1',
              'name': 'Bun bo Hue',
              'category': 'Noodle',
              'image_path': 'https://cdn.example.test/bun-bo.jpg',
              'rating': null,
              'review_count': 0,
            },
          ],
        };
      },
      mediaPublicBaseUrl: 'https://media.example.test',
    );

    final HomeFeaturedContent content = await repository.fetchFeaturedContent(
      limit: 4,
    );

    expect(requestedLimit, 4);
    expect(
      content.destinations.single.imagePath,
      'https://media.example.test/provinces/ha-tinh/cover.jpg',
    );
    expect(content.destinations.single.rating, 4.75);
    expect(content.destinations.single.reviewCount, 8);
    expect(content.dishes.single.rating, isNull);
    expect(content.dishes.single.reviewCount, 0);
  });

  test('maps malformed RPC arrays to empty content lists', () async {
    final HomeRepository repository = HomeRepository(
      rpcInvoker: (_) async => <String, dynamic>{'destinations': null},
    );

    final HomeFeaturedContent content = await repository.fetchFeaturedContent();

    expect(content.destinations, isEmpty);
    expect(content.dishes, isEmpty);
  });
}
