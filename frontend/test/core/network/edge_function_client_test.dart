import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/edge_function_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('postJson sends JSON body and Supabase auth headers', () async {
    http.Request? capturedRequest;
    final EdgeFunctionClient client = EdgeFunctionClient(
      baseUrl: 'https://example.supabase.co/',
      anonKey: 'anon-key',
      accessTokenProvider: () async => 'user-jwt',
      client: MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final Map<String, dynamic> result = await client.postJson(
      'translate',
      requireAuth: true,
      body: <String, Object?>{'action': 'translate', 'text': 'hello'},
    );

    expect(
      capturedRequest?.url.toString(),
      'https://example.supabase.co/functions/v1/translate',
    );
    expect(capturedRequest?.headers['apikey'], 'anon-key');
    expect(capturedRequest?.headers['Authorization'], 'Bearer user-jwt');
    expect(capturedRequest?.headers['authorization'], 'Bearer user-jwt');
    expect(
      capturedRequest?.headers['content-type'],
      contains('application/json'),
    );
    expect(jsonDecode(capturedRequest!.body), <String, Object?>{
      'action': 'translate',
      'text': 'hello',
    });
    expect(result['ok'], isTrue);
  });

  test('postJson refuses required auth when there is no user token', () async {
    bool wasCalled = false;
    final EdgeFunctionClient client = EdgeFunctionClient(
      accessTokenProvider: () async => null,
      client: MockClient((http.Request request) async {
        wasCalled = true;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => client.postJson('translate', requireAuth: true),
      throwsA(
        isA<EdgeFunctionException>().having(
          (EdgeFunctionException error) => error.message,
          'message',
          contains('Please sign in'),
        ),
      ),
    );
    expect(wasCalled, isFalse);
  });

  test('postJson maps HTTP error payloads', () async {
    final EdgeFunctionClient client = EdgeFunctionClient(
      client: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'error': 'BAD_REQUEST'}),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => client.postJson('currency-rates'),
      throwsA(
        isA<EdgeFunctionException>()
            .having(
              (EdgeFunctionException error) => error.message,
              'message',
              'BAD_REQUEST',
            )
            .having(
              (EdgeFunctionException error) => error.statusCode,
              'statusCode',
              400,
            ),
      ),
    );
  });

  test('postJson applies request timeout', () async {
    final EdgeFunctionClient client = EdgeFunctionClient(
      requestTimeout: const Duration(milliseconds: 10),
      client: MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => client.postJson('slow-function'),
      throwsA(isA<TimeoutException>()),
    );
  });
}
