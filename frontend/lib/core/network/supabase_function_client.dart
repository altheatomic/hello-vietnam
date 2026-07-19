import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SupabaseFunctionInvoker =
    Future<Object?> Function(
      String functionName, {
      Map<String, String>? headers,
      Object? body,
    });

class SupabaseFunctionException implements Exception {
  const SupabaseFunctionException(this.message, {this.details, this.errorCode});

  final String message;
  final Object? details;
  final String? errorCode;

  @override
  String toString() => message;
}

class SupabaseFunctionClient {
  SupabaseFunctionClient({
    SupabaseClient? client,
    FutureOr<String?> Function()? accessTokenProvider,
    SupabaseFunctionInvoker? invoker,
    Duration defaultTimeout = const Duration(seconds: 25),
  }) : _client = client,
       _accessTokenProvider =
           accessTokenProvider ?? (() => _defaultAccessTokenProvider(client)),
       _invoker = invoker,
       _defaultTimeout = defaultTimeout;

  final SupabaseClient? _client;
  final FutureOr<String?> Function() _accessTokenProvider;
  final SupabaseFunctionInvoker? _invoker;
  final Duration _defaultTimeout;

  Future<Map<String, dynamic>> invokeJson(
    String functionName, {
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String>? headers,
    bool requireAuth = false,
    Duration? timeout,
  }) async {
    final Object? rawData = await _invoke(
      functionName,
      body: body,
      headers: headers,
      requireAuth: requireAuth,
      timeout: timeout,
    );
    final Map<String, dynamic> data = _asMap(rawData);
    final Object? error = data['error'];
    if (error != null) {
      throw SupabaseFunctionException(
        error.toString(),
        details: data,
        errorCode: data['error_code'] as String?,
      );
    }
    return data;
  }

  Future<void> invokeVoid(
    String functionName, {
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String>? headers,
    bool requireAuth = false,
    Duration? timeout,
  }) async {
    final Object? rawData = await _invoke(
      functionName,
      body: body,
      headers: headers,
      requireAuth: requireAuth,
      timeout: timeout,
    );
    if (rawData == null) return;
    final Map<String, dynamic> data = _asMap(rawData);
    final Object? error = data['error'];
    if (error != null) {
      throw SupabaseFunctionException(
        error.toString(),
        details: data,
        errorCode: data['error_code'] as String?,
      );
    }
  }

  Future<Object?> _invoke(
    String functionName, {
    required Map<String, Object?> body,
    required Map<String, String>? headers,
    required bool requireAuth,
    required Duration? timeout,
  }) async {
    final String? accessToken = (await _accessTokenProvider())?.trim();
    if (requireAuth && (accessToken == null || accessToken.isEmpty)) {
      throw const SupabaseFunctionException(
        'Please sign in before using this feature.',
      );
    }

    final Map<String, String> requestHeaders = <String, String>{
      ...?headers,
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    final SupabaseFunctionInvoker invoker = _invoker ?? _defaultInvoker;
    try {
      return await invoker(
        functionName,
        headers: requestHeaders.isEmpty ? null : requestHeaders,
        body: body,
      ).timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      throw SupabaseFunctionException(
        'Request to $functionName timed out. Please try again.',
      );
    } on FunctionException catch (error) {
      // The functions_client SDK throws FunctionException itself for any
      // non-2xx response — invokeJson()/invokeVoid()'s `data['error']` check
      // never runs for real HTTP errors (e.g. 422 no_candidates), since the
      // SDK throws before returning a value to them. `error.details` holds
      // the *decoded* JSON body when the response was
      // Content-Type: application/json (every edge function here responds
      // with `{error, error_code?}` on failure — see e.g. trip_handler.ts's
      // jsonResponse()); otherwise `details` is the raw response string.
      // TEMP — remove after confirming the fix in practice:
      debugPrint(
        '[SupabaseFunctionClient] FunctionException for $functionName: '
        'status=${error.status} reasonPhrase=${error.reasonPhrase} '
        'details=${error.details} (${error.details.runtimeType})',
      );

      final Object? details = error.details;
      if (details is Map) {
        final Map<String, dynamic> map = details.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        );
        final Object? errorMessage = map['error'];
        if (errorMessage != null) {
          throw SupabaseFunctionException(
            errorMessage.toString(),
            details: map,
            errorCode: map['error_code'] as String?,
          );
        }
      }

      final String fallbackMessage = details is String && details.trim().isNotEmpty
          ? details
          : (error.reasonPhrase ?? 'Request failed (status ${error.status}).');
      throw SupabaseFunctionException(fallbackMessage, details: details);
    }
  }

  Future<Object?> _defaultInvoker(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final SupabaseClient client = _client ?? Supabase.instance.client;
    final FunctionResponse response = await client.functions.invoke(
      functionName,
      headers: headers,
      body: body,
    );
    return response.data;
  }

  static FutureOr<String?> _defaultAccessTokenProvider(SupabaseClient? client) {
    try {
      return (client ?? Supabase.instance.client)
          .auth
          .currentSession
          ?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(Object? rawData) {
    if (rawData == null) return <String, dynamic>{};
    if (rawData is Map<String, dynamic>) return rawData;
    if (rawData is Map) {
      return rawData.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    throw const SupabaseFunctionException(
      'Unexpected response from Supabase edge function.',
    );
  }
}
