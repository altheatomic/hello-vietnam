import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/item_detail/data/item_detail_repository.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

void main() {
  setUp(ItemDetailRepository.clearCache);

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
                  'coverImage': 'food/cover.jpg',
                  'galleryImages': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'gallery-1',
                      'alt': 'Gallery image',
                      'key': 'food/gallery.jpg',
                      'sort_order': 0,
                    },
                  ],
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
    expect(
      detail.coverImage,
      'https://pub-92f9bcecf7874fc4bcc402bde56011f7.r2.dev/food/cover.jpg',
    );
    expect(detail.galleryImages, <String>[
      'https://pub-92f9bcecf7874fc4bcc402bde56011f7.r2.dev/food/gallery.jpg',
    ]);
    expect(detail.reviewCount, 42);
  });

  test('reuses a cached detail request within the cache window', () async {
    int invocationCount = 0;
    final ItemDetailRepository repository = ItemDetailRepository(
      languageCodeProvider: () => 'en',
      functionClient: SupabaseFunctionClient(
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              invocationCount += 1;
              return <String, dynamic>{
                'item': <String, dynamic>{
                  'id': 'activity-1',
                  'name': 'Cached activity',
                  'category': 'activities',
                  'images': <String>['activity/cover.webp'],
                  'coverImage': 'activity/cover.webp',
                  'galleryImages': <String>[],
                  'rating': 4.5,
                  'reviewCount': 1,
                  'ratingLabel': 'Great',
                  'description': 'Description',
                  'whatToExpect': 'Expectation',
                },
              };
            },
      ),
    );
    const ItemDetailRequest request = ItemDetailRequest(
      id: 'activity-1',
      name: 'Activity',
      category: DetailCategory.activities,
    );

    await repository.load(request);
    await repository.load(request);

    expect(invocationCount, 1);
  });
}
