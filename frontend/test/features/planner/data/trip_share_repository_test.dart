import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('createShareLink sends an authenticated create action', () async {
    Object? capturedBody;
    final SupabaseFunctionClient functions = SupabaseFunctionClient(
      accessTokenProvider: () => 'access-token',
      invoker:
          (
            String functionName, {
            Map<String, String>? headers,
            Object? body,
          }) async {
            expect(functionName, 'trip-share');
            expect(headers?['Authorization'], 'Bearer access-token');
            capturedBody = body;
            return <String, dynamic>{
              'url': 'https://share.example.test/trip/token',
              'link': <String, dynamic>{
                'id_share': 'share-1',
                'id_plan': 'plan-1',
                'token_prefix': 'abcdefgh',
                'allow_copy': true,
                'expires_at': '2026-08-31T00:00:00Z',
                'revoked_at': null,
                'created_at': '2026-08-01T00:00:00Z',
              },
            };
          },
    );
    final TripRepository repository = TripRepository(functionClient: functions);

    final result = await repository.createShareLink(
      'plan-1',
      expiryDays: 30,
      allowCopy: true,
    );

    expect(capturedBody, <String, Object?>{
      'action': 'create',
      'idPlan': 'plan-1',
      'expiryDays': 30,
      'allowCopy': true,
    });
    expect(result.link.idShare, 'share-1');
  });

  test('getPublicSharedPlan calls the anonymous public GET endpoint', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'title': 'Shared trip',
          'n_days': 0,
          'days': <Object?>[],
          'allow_copy': true,
          'expires_at': '2026-08-31T00:00:00Z',
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final TripRepository repository = TripRepository(httpClient: client);

    final trip = await repository.getPublicSharedPlan('abc_123');

    expect(captured.method, 'GET');
    expect(
      captured.url.path,
      endsWith('/functions/v1/trip-share/public/abc_123'),
    );
    expect(captured.headers['apikey'], isNotEmpty);
    expect(trip.title, 'Shared trip');
  });
}
