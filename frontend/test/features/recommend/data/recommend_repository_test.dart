import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/recommend/data/recommend_repository.dart';

void main() {
  test(
    'resolves province cover and gallery keys from function responses',
    () async {
      final RecommendRepository repository = RecommendRepository(
        functionClient: SupabaseFunctionClient(
          accessTokenProvider: () => 'token',
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                return <String, dynamic>{
                  'provinces': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id_province': 'p1',
                      'name': 'Ha Tinh',
                      'description': 'Coastal',
                      'cover_image': 'province/p1/cover.jpg',
                      'gallery': <String>['province/p1/one.jpg'],
                      'avg_rating': 4.6,
                      'review_count': 5,
                    },
                  ],
                };
              },
        ),
        mediaResolver: (String raw) => 'https://media.test/$raw',
      );

      final result = await repository.getPersonalizedProvinces();

      expect(
        result.single.imagePath,
        'https://media.test/province/p1/cover.jpg',
      );
      expect(result.single.gallery, <String>[
        'https://media.test/province/p1/one.jpg',
      ]);
      expect(result.single.reviewCount, 5);
    },
  );

  test('resolves top-place gallery keys from province detail responses', () {
    final ProvinceTopPlace place = ProvinceTopPlace.fromJson(<String, dynamic>{
      'id_place': 'place-1',
      'name': 'Gallery place',
      'cover_image': 'places/place-1/cover.jpg',
      'gallery': <String>['places/place-1/one.jpg', 'places/place-1/two.jpg'],
    }, mediaResolver: (String raw) => 'https://media.test/$raw');

    expect(place.coverImage, 'https://media.test/places/place-1/cover.jpg');
    expect(place.gallery, <String>[
      'https://media.test/places/place-1/one.jpg',
      'https://media.test/places/place-1/two.jpg',
    ]);
  });

  test('maps nullable detailed description for individual place detail', () {
    final ProvinceTopPlace place = ProvinceTopPlace.fromJson(<String, dynamic>{
      'id_place': 'place-1',
      'name': 'Detail place',
      'short_description': 'Short copy',
      'detailed_description': 'Long detail copy',
    });

    expect(place.shortDescription, 'Short copy');
    expect(place.detailedDescription, 'Long detail copy');
  });
}
