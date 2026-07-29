import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/admin/data/admin_food_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'fetchFoods loads a paged food table directly through shared table client',
    () async {
      final _FakeFoodTableClient tableClient = _FakeFoodTableClient(
        responses: <String, Object?>{
          'food page': _FakePostgrestPage(
            data: <Map<String, dynamic>>[
              <String, dynamic>{
                'id_food': 'food-1',
                'name': 'Pho',
                'food_type_id': 'noodles',
                'id_province': 'province-1',
                'image_path': 'foods/pho.jpg',
                'description': 'Noodle soup',
              },
            ],
            count: 42,
          ),
          'province lookup': <Map<String, dynamic>>[
            <String, dynamic>{'id_province': 'province-1', 'name': 'Ha Noi'},
          ],
        },
      );
      final AdminFoodRepository repository = AdminFoodRepository(
        client: SupabaseClient('https://example.supabase.co', 'anon-key'),
        tableClient: tableClient,
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                fail('fetchFoods should not call $functionName.');
              },
        ),
      );

      final AdminFoodPageResult result = await repository.fetchFoods(
        page: 2,
        pageSize: 8,
        query: 'pho',
        typeId: 'noodles',
        sortField: 'name',
        sortDirection: 'descending',
      );

      expect(tableClient.runLabels, <String>['food page', 'province lookup']);
      expect(result.totalCount, 42);
      expect(result.foods.single.id, 'food-1');
      expect(result.foods.single.name, 'Pho');
      expect(result.foods.single.typeId, 'noodles');
      expect(result.foods.single.city, 'Ha Noi');
      expect(result.foods.single.urlImage, 'foods/pho.jpg');
      expect(result.foods.single.description, 'Noodle soup');
    },
  );
}

class _FakePostgrestPage {
  const _FakePostgrestPage({required this.data, required this.count});

  final List<Map<String, dynamic>> data;
  final int count;
}

class _FakeFoodTableClient extends SupabaseTableClient {
  _FakeFoodTableClient({required this.responses});

  final Map<String, Object?> responses;
  final List<String> runLabels = <String>[];

  @override
  Future<T> run<T>(
    String label,
    Future<T> Function() request, {
    Duration? timeout,
  }) async {
    runLabels.add(label);
    final Object? response = responses[label];
    if (!responses.containsKey(label)) {
      throw StateError('No fake response for $label.');
    }
    return response as T;
  }
}
