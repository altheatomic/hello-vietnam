import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/item_detail/data/item_detail_repository.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

void main() {
  test('loads a live item detail by category and id', () async {
    Object? capturedBody;
    final ItemDetailRepository repository = ItemDetailRepository(
      languageCodeProvider: () => 'vi',
      functionClient: SupabaseFunctionClient(
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              capturedBody = body;
              return <String, dynamic>{
                'item': <String, dynamic>{
                  'id': 'food-1',
                  'reviewContentId': 'food-1',
                  'name': 'Bun bo Hue',
                  'category': 'food',
                  'images': <String>['food/cover.jpg', 'food/gallery.jpg'],
                  'rating': 4.8,
                  'reviewCount': 42,
                  'ratingLabel': 'Excellent',
                  'description': 'A signature Hue noodle soup.',
                  'whatToExpect': 'Rich broth and fresh herbs.',
                },
              };
            },
      ),
    );

    final ItemDetail detail = await repository.load(
      const ItemDetailRequest(
        id: 'food-1',
        name: 'Fallback name',
        category: DetailCategory.food,
      ),
    );

    expect(capturedBody, <String, Object?>{
      'action': 'getExploreItemDetail',
      'category': 'food',
      'id': 'food-1',
      'language': 'vi',
    });
    expect(detail.name, 'Bun bo Hue');
    expect(detail.images, <String>[
      'https://pub-92f9bcecf7874fc4bcc402bde56011f7.r2.dev/food/cover.jpg',
      'https://pub-92f9bcecf7874fc4bcc402bde56011f7.r2.dev/food/gallery.jpg',
    ]);
    expect(detail.reviewCount, 42);
  });
}
