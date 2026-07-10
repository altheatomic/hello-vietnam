import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/home/data/home_repository.dart';

void main() {
  test(
    'fetchFeaturedContent reads destinations and dishes through table client',
    () async {
      final _FakeTableClient tableClient = _FakeTableClient(
        rowsByLabel: <String, List<Map<String, dynamic>>>{
          'featured provinces': <Map<String, dynamic>>[
            <String, dynamic>{
              'id_province': 'province-1',
              'name': 'Da Nang',
              'short_description': 'Beach city',
            },
          ],
          'featured foods': <Map<String, dynamic>>[
            <String, dynamic>{
              'id_food': 'food-1',
              'name': 'Bun bo Hue',
              'type': 'Noodle',
              'image_path': 'https://example.test/bun-bo.jpg',
            },
          ],
        },
      );

      final HomeRepository repository = HomeRepository(
        tableClient: tableClient,
      );

      final HomeFeaturedContent content = await repository.fetchFeaturedContent(
        limit: 1,
      );

      expect(tableClient.listLabels, <String>[
        'featured provinces',
        'featured foods',
      ]);
      expect(content.destinations.single.name, 'Da Nang');
      expect(content.dishes.single.name, 'Bun bo Hue');
    },
  );
}

class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({required this.rowsByLabel});

  final Map<String, List<Map<String, dynamic>>> rowsByLabel;
  final List<String> listLabels = <String>[];

  @override
  Future<List<Map<String, dynamic>>> list(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    listLabels.add(label);
    return rowsByLabel[label] ?? const <Map<String, dynamic>>[];
  }
}
