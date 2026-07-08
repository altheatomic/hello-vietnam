import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/profile/data/currency_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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