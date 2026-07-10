import 'dart:async';
import 'dart:convert';

import 'package:hellovietnam/core/config/env.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EdgeFunctionException implements Exception {
  const EdgeFunctionException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

class EdgeFunctionClient {
  EdgeFunctionClient({
    http.Client? client,
    Future<String?> Function()? accessTokenProvider,
    Duration requestTimeout = const Duration(seconds: 20),
    String? baseUrl,
    String? anonKey,
  }) : _client = client ?? http.Client(),
       _accessTokenProvider =
           accessTokenProvider ?? _defaultAccessTokenProvider,
       _requestTimeout = requestTimeout,
       _baseUrl = _normalizeBaseUrl(baseUrl ?? Env.supabaseUrl),
       _anonKey = anonKey ?? Env.supabaseAnonKey;

  final http.Client _client;
  final Future<String?> Function() _accessTokenProvider;
  final Duration _requestTimeout;
  final String _baseUrl;
  final String _anonKey;

  Future<Map<String, dynamic>> postJson(
    String functionName, {
    Map<String, Object?> body = const <String, Object?>{},
    bool requireAuth = false,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final String trimmedFunctionName = functionName.trim();
    if (trimmedFunctionName.isEmpty) {
      throw const EdgeFunctionException('Edge function name is required.');
    }

    final String? accessToken = await _accessTokenProvider();
    final String? normalizedToken = accessToken?.trim();
    if (requireAuth && (normalizedToken == null || normalizedToken.isEmpty)) {
      throw const EdgeFunctionException(
        'Please sign in before using this feature.',
      );
    }

    final Map<String, String> requestHeaders = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json; charset=utf-8',
      'apikey': _anonKey,
      ...headers,
    };
    if (normalizedToken != null && normalizedToken.isNotEmpty) {
      requestHeaders['Authorization'] = 'Bearer $normalizedToken';
      requestHeaders['authorization'] = 'Bearer $normalizedToken';
    }

    final http.Response response = await _client
        .post(
          _uriFor(trimmedFunctionName),
          headers: requestHeaders,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    final Map<String, dynamic> data = _decodeResponse(response);
    final Object? serverError = data['error'];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EdgeFunctionException(
        serverError?.toString() ??
            'Edge function $trimmedFunctionName failed (${response.statusCode}).',
        statusCode: response.statusCode,
        details: data,
      );
    }

    if (serverError != null) {
      throw EdgeFunctionException(
        serverError.toString(),
        statusCode: response.statusCode,
        details: data,
      );
    }

    return data;
  }

  Uri _uriFor(String functionName) {
    return Uri.parse('$_baseUrl/functions/v1/$functionName');
  }

  static Future<String?> _defaultAccessTokenProvider() async {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final String body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) return <String, dynamic>{};

    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{'error': body};
      }
    }

    throw const EdgeFunctionException(
      'Edge function returned an invalid JSON response.',
    );
  }
}
