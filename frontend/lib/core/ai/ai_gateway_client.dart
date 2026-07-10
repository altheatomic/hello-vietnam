import 'package:hellovietnam/core/network/supabase_function_client.dart';
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
  AiGatewayClient({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
  }) : _functionClient =
           functionClient ??
           SupabaseFunctionClient(client: client ?? Supabase.instance.client);

  final SupabaseFunctionClient _functionClient;

  Future<AiGatewayResponse> invoke({
    required String feature,
    required Map<String, dynamic> input,
    String language = 'en',
    String? modelMode,
    bool useCache = true,
  }) async {
    try {
      final Map<String, dynamic> data = await _functionClient.invokeJson(
        'ai-gateway',
        body: <String, dynamic>{
          'feature': feature,
          'language': language,
          'input': input,
          'useCache': useCache,
          if (modelMode case final String value) 'modelMode': value,
        },
      );
      return AiGatewayResponse.fromJson(data);
    } on SupabaseFunctionException catch (error) {
      throw AiGatewayException(error.message);
    }
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
