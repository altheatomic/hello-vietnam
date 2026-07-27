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
}
