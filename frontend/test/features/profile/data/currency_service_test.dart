import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/profile/data/currency_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'SupabaseCurrencyAccountStore reads account currency via table client',
    () async {
      final _FakeTableClient tableClient = _FakeTableClient(
        maybeSingleRows: <Map<String, dynamic>?>[
          <String, dynamic>{'currency': 'eur'},
        ],
      );
      final SupabaseCurrencyAccountStore store = SupabaseCurrencyAccountStore(
        tableClient: tableClient,
      );

      final String? currency = await store.loadSelectedCurrency('user-1');

      expect(currency, 'EUR');
      expect(tableClient.maybeSingleLabels, <String>['user account currency']);
    },
  );

  test(
    'SupabaseCurrencyAccountStore falls back to user_setting currency',
    () async {
      final _FakeTableClient tableClient = _FakeTableClient(
        maybeSingleRows: <Map<String, dynamic>?>[
          null,
          <String, dynamic>{'currency': 'vnd'},
        ],
      );
      final SupabaseCurrencyAccountStore store = SupabaseCurrencyAccountStore(
        tableClient: tableClient,
      );

      final String? currency = await store.loadSelectedCurrency('user-1');

      expect(currency, 'VND');
      expect(tableClient.maybeSingleLabels, <String>[
        'user account currency',
        'user setting currency',
      ]);
    },
  );

  test('CurrencyRatesGateway parses the edge function response', () async {
    http.Request? capturedRequest;
    final CurrencyRatesGateway gateway = CurrencyRatesGateway(
      accessTokenProvider: () async => 'user-jwt',
      client: MockClient((http.Request request) async {
        capturedRequest = request;
        expect(request.url.path, endsWith('/functions/v1/currency-rates'));
        return http.Response(
          jsonEncode(<String, Object?>{
            'provider': 'open-er-api',
            'base_code': 'USD',
            'updated_at': '2026-07-01T00:00:00Z',
            'rates': <String, Object?>{
              'VND': 26255.877531,
              'KRW': 1548.629377,
              'CNY': 7.196501,
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final CurrencyRatesSnapshot snapshot = await gateway.fetchRates(
      baseCode: 'USD',
      symbols: <String>['VND', 'KRW', 'CNY'],
    );

    expect(capturedRequest?.headers['authorization'], 'Bearer user-jwt');
    expect(capturedRequest?.headers['apikey'], isNotNull);
    expect(snapshot.baseCode, 'USD');
    expect(snapshot.provider, 'open-er-api');
    expect(snapshot.rateFor('VND'), 26255.877531);
    expect(snapshot.rateFor('KRW'), 1548.629377);
    expect(snapshot.rateFor('CNY'), 7.196501);
  });

  test('CurrencyCacheRecord round-trips through JSON', () {
    final CurrencyCacheRecord record = CurrencyCacheRecord(
      selectedCode: 'VND',
      snapshot: CurrencyRatesSnapshot(
        baseCode: 'USD',
        provider: 'open-er-api',
        updatedAt: DateTime.parse('2026-07-01T00:00:00Z'),
        rates: <String, double>{'VND': 26255.877531},
      ),
    );

    final CurrencyCacheRecord parsed = CurrencyCacheRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );

    expect(parsed.selectedCode, 'VND');
    expect(parsed.snapshot.baseCode, 'USD');
    expect(parsed.snapshot.rateFor('VND'), 26255.877531);
  });
}

class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({required List<Map<String, dynamic>?> maybeSingleRows})
    : _maybeSingleRows = List<Map<String, dynamic>?>.of(maybeSingleRows);

  final List<Map<String, dynamic>?> _maybeSingleRows;
  final List<String> maybeSingleLabels = <String>[];

  @override
  Future<Map<String, dynamic>?> maybeSingle(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    maybeSingleLabels.add(label);
    if (_maybeSingleRows.isEmpty) return null;
    return _maybeSingleRows.removeAt(0);
  }
}
