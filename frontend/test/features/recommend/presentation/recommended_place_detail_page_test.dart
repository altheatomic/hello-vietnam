import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/recommend/data/recommend_repository.dart';
import 'package:hellovietnam/features/recommend/presentation/recommended_place_detail_page.dart';

void main() {
  test('prefers long detail copy, then short copy, then category/address', () {
    ProvinceTopPlace placeWithLongCopy = const ProvinceTopPlace(
      idPlace: 'place-1',
      name: 'Pagoda',
      detailedDescription: 'Grounded long description.',
      shortDescription: 'Short description.',
      subcategoryName: 'Pagoda',
      address: 'Huế',
    );
    expect(
      recommendedPlaceDescription(placeWithLongCopy),
      'Grounded long description.',
    );

    placeWithLongCopy = const ProvinceTopPlace(
      idPlace: 'place-1',
      name: 'Pagoda',
      detailedDescription: '  ',
      shortDescription: 'Short description.',
      subcategoryName: 'Pagoda',
      address: 'Huế',
    );
    expect(recommendedPlaceDescription(placeWithLongCopy), 'Short description.');

    const ProvinceTopPlace fallbackPlace = ProvinceTopPlace(
      idPlace: 'place-1',
      name: 'Pagoda',
      subcategoryName: 'Pagoda',
      address: 'Huế',
    );
    expect(recommendedPlaceDescription(fallbackPlace), 'Pagoda · Huế');
  });

  test('detail loading calls the individual place endpoint even with a province', () async {
    final List<String> actions = <String>[];
    final RecommendRepository repository = RecommendRepository(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () => 'token',
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              final Map<String, dynamic> request = body! as Map<String, dynamic>;
              actions.add(request['action']! as String);
              return <String, dynamic>{
                'place': <String, dynamic>{
                  'id_place': 'place-1',
                  'name': 'Place',
                },
              };
            },
      ),
    );

    await loadRecommendedPlaceDetail(repository, 'place-1');

    expect(actions, <String>['getPlaceById']);
  });
}
