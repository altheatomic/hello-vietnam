import 'dart:convert';

import 'package:hellovietnam/core/config/env.dart';
import 'package:http/http.dart' as http;

class TranslationException implements Exception {
  TranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TranslationResult {
  const TranslationResult({
    required this.translatedText,
    this.detectedSourceLanguageCode,
  });

  final String translatedText;
  final String? detectedSourceLanguageCode;
}

class OpenAITranslationService {
  OpenAITranslationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
    required String targetLanguageName,
  }) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return const TranslationResult(translatedText: '');
    }

    try {
      final Uri uri = Uri.parse('${Env.supabaseUrl}/functions/v1/translate');
      final http.Response response = await _client.post(
        uri,
        headers: <String, String>{
          'apikey': Env.supabaseAnonKey,
          'Authorization': 'Bearer ${Env.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'text': trimmedText,
          'sourceLanguageCode': sourceLanguageCode,
          'targetLanguageCode': targetLanguageCode,
          'targetLanguageName': targetLanguageName,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        throw TranslationException(
          _mapServerError(
            (data['error'] as String?) ?? 'Translate function failed (${response.statusCode}).',
          ),
        );
      }

      if (data.isEmpty) {
        throw TranslationException('Translate function returned an invalid response.');
      }

      return TranslationResult(
        translatedText: (data['translation'] as String? ?? '').trim(),
        detectedSourceLanguageCode:
            (data['detected_source_language_code'] as String?)?.trim(),
      );
    } on TranslationException {
      rethrow;
    } catch (error) {
      throw TranslationException(_mapServerError(error.toString()));
    }
  }

  String _mapServerError(String rawMessage) {
    final String lowerMessage = rawMessage.toLowerCase();

    if (lowerMessage.contains('missing authorization header') ||
        lowerMessage.contains('invalid jwt')) {
      return 'Supabase auth config dang sai. Hay kiem tra lai supabaseUrl va anon key.';
    }

    if (lowerMessage.contains('server is missing gemini_api_key')) {
      return 'Chua cau hinh GEMINI_API_KEY tren Supabase secrets.';
    }

    if (lowerMessage.contains('api key not valid')) {
      return 'Gemini API key khong hop le. Hay tao key moi va cap nhat Supabase secrets.';
    }

    if (lowerMessage.contains('quota') ||
        lowerMessage.contains('rate limit') ||
        lowerMessage.contains('resource has been exhausted')) {
      return 'Gemini dang vuot gioi han free tier hoac quota. Hay doi mot luc hoac nang cap quota.';
    }

    if (lowerMessage.contains('permission') ||
        lowerMessage.contains('not enabled') ||
        lowerMessage.contains('forbidden')) {
      return 'Gemini API chua duoc bat hoac project khong du quyen truy cap.';
    }

    if (lowerMessage.contains('invalid json body')) {
      return 'Request translate gui len server khong hop le.';
    }

    return rawMessage;
  }
}
