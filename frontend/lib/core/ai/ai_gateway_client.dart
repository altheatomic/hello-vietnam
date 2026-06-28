import 'package:supabase_flutter/supabase_flutter.dart';

class AiGatewayException implements Exception {
  const AiGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiGatewayResponse {
  const AiGatewayResponse({
    required this.feature,
    required this.provider,
    required this.model,
    required this.cached,
    required this.result,
    this.usage,
  });

  final String feature;
  final String provider;
  final String model;
  final bool cached;
  final Map<String, dynamic> result;
  final Map<String, dynamic>? usage;

  factory AiGatewayResponse.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return AiGatewayResponse(
      feature: json['feature']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      cached: json['cached'] == true,
      result: rawResult is Map
          ? Map<String, dynamic>.from(rawResult.cast<String, dynamic>())
          : <String, dynamic>{},
      usage: json['usage'] is Map
          ? Map<String, dynamic>.from(
              (json['usage'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class AiGatewayClient {
  AiGatewayClient({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AiGatewayResponse> invoke({
    required String feature,
    required Map<String, dynamic> input,
    String language = 'en',
    String? modelMode,
    bool useCache = true,
  }) async {
    final Session? session = _client.auth.currentSession;
    final Map<String, String> headers = <String, String>{};
    if (session?.accessToken case final String token) {
      headers['Authorization'] = 'Bearer $token';
    }

    final FunctionResponse response = await _client.functions.invoke(
      'ai-gateway',
      headers: headers.isEmpty ? null : headers,
      body: <String, dynamic>{
        'feature': feature,
        'language': language,
        'input': input,
        'useCache': useCache,
        if (modelMode case final String value) 'modelMode': value,
      },
    );

    final dynamic data = response.data;
    if (data is Map && data['error'] != null) {
      throw AiGatewayException(data['error'].toString());
    }
    if (data is Map<String, dynamic>) {
      return AiGatewayResponse.fromJson(data);
    }
    if (data is Map) {
      return AiGatewayResponse.fromJson(Map<String, dynamic>.from(data));
    }

    throw const AiGatewayException('Unexpected response from AI gateway.');
  }

  Future<String> translate({
    required String text,
    String sourceLanguageCode = 'auto',
    required String targetLanguageCode,
    required String targetLanguageName,
  }) async {
    final response = await invoke(
      feature: 'translate',
      language: targetLanguageCode,
      input: <String, dynamic>{
        'text': text,
        'source_language_code': sourceLanguageCode,
        'target_language_code': targetLanguageCode,
        'target_language_name': targetLanguageName,
      },
    );
    return response.result['translation']?.toString().trim() ?? '';
  }
}
