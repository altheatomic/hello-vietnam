import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';

void main() {
  test('list normalizes dynamic map rows', () async {
    final SupabaseTableClient client = SupabaseTableClient();

    final List<Map<String, dynamic>> rows = await client.list(
      'foods',
      () async => <Object?>[
        <Object?, Object?>{'id': 1, 'name': 'Pho'},
      ],
    );

    expect(rows, hasLength(1));
    expect(rows.single, <String, Object?>{'id': 1, 'name': 'Pho'});
  });

  test('maybeSingle returns null for an empty response', () async {
    final SupabaseTableClient client = SupabaseTableClient();

    final Map<String, dynamic>? row = await client.maybeSingle(
      'subscription plan',
      () async => null,
    );

    expect(row, isNull);
  });

  test('single rejects missing rows with a table exception', () async {
    final SupabaseTableClient client = SupabaseTableClient();

    expect(
      () => client.single('subscription plan', () async => null),
      throwsA(isA<SupabaseTableException>()),
    );
  });

  test('rangeForPage returns inclusive Supabase ranges', () {
    final SupabaseTableRange firstPage = SupabaseTableClient.rangeForPage(
      page: 1,
      pageSize: 20,
    );
    final SupabaseTableRange thirdPage = SupabaseTableClient.rangeForPage(
      page: 3,
      pageSize: 20,
    );

    expect(firstPage.from, 0);
    expect(firstPage.to, 19);
    expect(thirdPage.from, 40);
    expect(thirdPage.to, 59);
  });

  test('list maps timeouts to a friendly exception', () async {
    final SupabaseTableClient client = SupabaseTableClient(
      defaultTimeout: const Duration(milliseconds: 1),
    );

    expect(
      () => client.list('foods', () => Completer<Object?>().future),
      throwsA(
        isA<SupabaseTableException>().having(
          (SupabaseTableException error) => error.message,
          'message',
          contains('foods timed out'),
        ),
      ),
    );
  });

  test(
    'run applies the shared timeout and returns arbitrary responses',
    () async {
      final SupabaseTableClient client = SupabaseTableClient();

      final Map<String, Object?> response = await client.run(
        'admin content page',
        () async => <String, Object?>{'count': 3},
      );

      expect(response, <String, Object?>{'count': 3});
    },
  );

  test('pagedRows normalizes Postgrest responses with count', () async {
    final SupabaseTableClient client = SupabaseTableClient();

    final SupabasePagedRows response = await client.pagedRows(
      'admin content page',
      () async => _FakePostgrestPage(
        data: <Object?>[
          <Object?, Object?>{'id': 1, 'name': 'Hoi An'},
        ],
        count: 24,
      ),
    );

    expect(response.rows, <Map<String, Object?>>[
      <String, Object?>{'id': 1, 'name': 'Hoi An'},
    ]);
    expect(response.totalCount, 24);
  });

  test('pagedRows accepts plain list responses', () async {
    final SupabaseTableClient client = SupabaseTableClient();

    final SupabasePagedRows response = await client.pagedRows(
      'admin content page',
      () async => <Object?>[
        <Object?, Object?>{'id': 1, 'name': 'Hoi An'},
      ],
    );

    expect(response.rows, <Map<String, Object?>>[
      <String, Object?>{'id': 1, 'name': 'Hoi An'},
    ]);
    expect(response.totalCount, isNull);
  });
}

class _FakePostgrestPage {
  const _FakePostgrestPage({required this.data, required this.count});

  final List<Object?> data;
  final int count;
}
