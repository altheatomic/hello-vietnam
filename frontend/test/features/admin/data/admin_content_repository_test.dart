import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/admin/data/admin_content_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_content.dart';

void main() {
  test('listSelectColumnsFor keeps admin lists narrow', () {
    final AdminContentRepository repository = AdminContentRepository();

    final List<String> columns = repository
        .listSelectColumnsFor(AdminContentConfigs.place)
        .split(', ')
        .toList(growable: false);

    expect(
      columns,
      containsAll(<String>[
        'id_place',
        'created_at',
        'name',
        'short_description',
        'address',
        'timespan',
        'timeclose',
        'status',
      ]),
    );
    expect(columns, isNot(contains('gallery')));
    expect(columns, isNot(contains('detailed_description')));
    expect(columns, isNot(contains('latitude')));
    expect(columns, isNot(contains('longitude')));
  });

  test('detailSelectColumnsFor includes editable hidden fields', () {
    final AdminContentRepository repository = AdminContentRepository();

    final List<String> columns = repository
        .detailSelectColumnsFor(AdminContentConfigs.localProduct)
        .split(', ')
        .toList(growable: false);

    expect(
      columns,
      containsAll(<String>[
        'id',
        'name',
        'short_description',
        'detailed_description',
        'storage_transport',
        'trusted_places',
        'gallery',
        'id_province',
      ]),
    );
  });

  test('select projections only request schema-backed primary keys', () {
    final AdminContentRepository repository = AdminContentRepository();
    final Map<AdminContentResourceConfig, List<String>> unsupportedColumns =
        <AdminContentResourceConfig, List<String>>{
          AdminContentConfigs.province: <String>[
            'id_city',
            'province_id',
            'id',
          ],
          AdminContentConfigs.activity: <String>['id_activity'],
          AdminContentConfigs.culture: <String>['id_culture'],
          AdminContentConfigs.localProduct: <String>['id_local_product'],
        };

    for (final entry in unsupportedColumns.entries) {
      final List<String> listColumns = repository
          .listSelectColumnsFor(entry.key)
          .split(', ');
      final List<String> detailColumns = repository
          .detailSelectColumnsFor(entry.key)
          .split(', ');

      expect(listColumns, contains(entry.key.idColumn));
      expect(detailColumns, contains(entry.key.idColumn));
      for (final unsupportedColumn in entry.value) {
        expect(
          listColumns,
          isNot(contains(unsupportedColumn)),
          reason:
              '${entry.key.table} list must not query $unsupportedColumn',
        );
        expect(
          detailColumns,
          isNot(contains(unsupportedColumn)),
          reason:
              '${entry.key.table} detail must not query $unsupportedColumn',
        );
      }
    }
  });

  test('select projections do not request legacy field aliases', () {
    final AdminContentRepository repository = AdminContentRepository();
    final List<String> unsupportedAliases = <String>[
      'province_name',
      'city',
      'city_name',
    ];

    final List<String> listColumns = repository
        .listSelectColumnsFor(AdminContentConfigs.province)
        .split(', ');
    final List<String> detailColumns = repository
        .detailSelectColumnsFor(AdminContentConfigs.province)
        .split(', ');

    expect(listColumns, contains('name'));
    expect(detailColumns, contains('name'));
    for (final alias in unsupportedAliases) {
      expect(listColumns, isNot(contains(alias)));
      expect(detailColumns, isNot(contains(alias)));
    }
  });

  test(
    'fetchRecord loads a full row through the shared table client',
    () async {
      final _FakeTableClient tableClient = _FakeTableClient(
        singleRow: <String, dynamic>{
          'id_place': 'place-1',
          'name': 'Hoi An Ancient Town',
          'detailed_description': 'Full admin detail',
        },
      );
      final AdminContentRepository repository = AdminContentRepository(
        tableClient: tableClient,
      );

      final AdminContentRecord record = await repository.fetchRecord(
        AdminContentConfigs.place,
        const AdminContentRecord(
          id: 'place-1',
          idColumn: 'id_place',
          values: <String, dynamic>{'id_place': 'place-1'},
        ),
      );

      expect(tableClient.singleLabels, <String>['place detail']);
      expect(record.id, 'place-1');
      expect(record.text('detailed_description'), 'Full admin detail');
    },
  );
}

class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({required this.singleRow});

  final Map<String, dynamic> singleRow;
  final List<String> singleLabels = <String>[];

  @override
  Future<Map<String, dynamic>> single(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    singleLabels.add(label);
    return singleRow;
  }
}
