import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';

void main() {
  test(
    'invokeJson forwards body and bearer token to Supabase functions',
    () async {
      String? capturedFunctionName;
      Map<String, String>? capturedHeaders;
      Object? capturedBody;

      final SupabaseFunctionClient client = SupabaseFunctionClient(
        accessTokenProvider: () async => 'user-jwt',
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              capturedFunctionName = functionName;
              capturedHeaders = headers;
              capturedBody = body;
              return <String, Object?>{'ok': true};
            },
      );

      final Map<String, dynamic> result = await client.invokeJson(
        'wishlist',
        requireAuth: true,
        body: <String, Object?>{'action': 'listWishlist'},
      );

      expect(capturedFunctionName, 'wishlist');
      expect(capturedHeaders, <String, String>{
        'Authorization': 'Bearer user-jwt',
      });
      expect(capturedBody, <String, Object?>{'action': 'listWishlist'});
      expect(result['ok'], isTrue);
    },
  );

  test(
    'invokeJson rejects required auth before invoking the function',
    () async {
      bool wasCalled = false;
      final SupabaseFunctionClient client = SupabaseFunctionClient(
        accessTokenProvider: () async => null,
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              wasCalled = true;
              return <String, Object?>{};
            },
      );

      expect(
        () => client.invokeJson('wishlist', requireAuth: true),
        throwsA(
          isA<SupabaseFunctionException>().having(
            (SupabaseFunctionException error) => error.message,
            'message',
            contains('Please sign in'),
          ),
        ),
      );
      expect(wasCalled, isFalse);
    },
  );

  test('invokeJson maps edge function error payloads', () async {
    final SupabaseFunctionClient client = SupabaseFunctionClient(
      invoker:
          (
            String functionName, {
            Map<String, String>? headers,
            Object? body,
          }) async {
            return <String, Object?>{'error': 'ACTION_FAILED'};
          },
    );

    expect(
      () => client.invokeJson('admin-food'),
      throwsA(
        isA<SupabaseFunctionException>().having(
          (SupabaseFunctionException error) => error.message,
          'message',
          'ACTION_FAILED',
        ),
      ),
    );
  });

  test('invokeJson accepts dynamic map responses', () async {
    final SupabaseFunctionClient client = SupabaseFunctionClient(
      invoker:
          (
            String functionName, {
            Map<String, String>? headers,
            Object? body,
          }) async {
            return <Object?, Object?>{'items': <Object?>[]};
          },
    );

    final Map<String, dynamic> result = await client.invokeJson('explore');

    expect(result['items'], isA<List<Object?>>());
  });

  test('invokeVoid ignores empty function responses', () async {
    final SupabaseFunctionClient client = SupabaseFunctionClient(
      invoker:
          (
            String functionName, {
            Map<String, String>? headers,
            Object? body,
          }) async {
            return null;
          },
    );

    await expectLater(client.invokeVoid('media-upload'), completes);
  });

  test('invokeJson maps slow function calls to timeout exception', () async {
    final SupabaseFunctionClient client = SupabaseFunctionClient(
      invoker:
          (String functionName, {Map<String, String>? headers, Object? body}) {
            return Completer<Object?>().future;
          },
    );

    expect(
      () => client.invokeJson(
        'slow-function',
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<SupabaseFunctionException>().having(
          (SupabaseFunctionException error) => error.message,
          'message',
          contains('slow-function timed out'),
        ),
      ),
    );
  });
}
