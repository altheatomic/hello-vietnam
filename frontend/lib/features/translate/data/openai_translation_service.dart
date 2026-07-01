import 'dart:convert';

import 'package:hellovietnam/core/config/env.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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

class OnlineSpeechResult {
  const OnlineSpeechResult({
    required this.audioUrl,
    this.provider,
    this.requestId,
  });

  final String audioUrl;
  final String? provider;
  final String? requestId;
}

class OpenAITranslationService {
  OpenAITranslationService({
    http.Client? client,
    Future<String?> Function()? accessTokenProvider,
  }) : _client = client ?? http.Client(),
       _accessTokenProvider = accessTokenProvider ?? _currentAccessToken;

  final http.Client _client;
  final Future<String?> Function() _accessTokenProvider;

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
        headers: await _authorizedHeaders(),
        body: jsonEncode(<String, String>{
          'action': 'translate',
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
            (data['error'] as String?) ??
                'Translate function failed (${response.statusCode}).',
          ),
        );
      }

      if (data.isEmpty) {
        throw TranslationException(
          'Translate function returned an invalid response.',
        );
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

  Future<OnlineSpeechResult> synthesizeSpeech({
    required String text,
    required String languageCode,
    required String languageName,
  }) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw TranslationException('Text-to-speech text is required.');
    }

    try {
      final Uri uri = Uri.parse('${Env.supabaseUrl}/functions/v1/translate');
      final http.Response response = await _client.post(
        uri,
        headers: await _authorizedHeaders(),
        body: jsonEncode(<String, String>{
          'action': 'tts',
          'text': trimmedText,
          'languageCode': languageCode,
          'languageName': languageName,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        throw TranslationException(
          _mapServerError(
            (data['error'] as String?) ??
                'Text-to-speech failed (${response.statusCode}).',
          ),
        );
      }

      final String audioUrl = (data['audio_url'] as String? ?? '').trim();
      if (audioUrl.isEmpty) {
        throw TranslationException(
          'Text-to-speech returned an invalid audio url.',
        );
      }

      return OnlineSpeechResult(
        audioUrl: audioUrl,
        provider: (data['provider'] as String?)?.trim(),
        requestId: (data['request_id'] as String?)?.trim(),
      );
    } on TranslationException {
      rethrow;
    } catch (error) {
      throw TranslationException(_mapServerError(error.toString()));
    }
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final String? accessToken = await _accessTokenProvider();
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw TranslationException(
        'Please sign in before using online translation.',
      );
    }

    return <String, String>{
      'apikey': Env.supabaseAnonKey,
      'Authorization': 'Bearer ${accessToken.trim()}',
      'Content-Type': 'application/json',
    };
  }

  static Future<String?> _currentAccessToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  String _mapServerError(String rawMessage) {
    final String lowerMessage = rawMessage.toLowerCase();

    if (lowerMessage.contains('missing authorization header') ||
        lowerMessage.contains('invalid jwt')) {
      return 'Supabase auth config dang sai. Hay kiem tra lai supabaseUrl va anon key.';
    }

    if (lowerMessage.contains('server is missing deepseek_api_key')) {
      return 'Chua cau hinh DEEPSEEK_API_KEY tren Supabase secrets.';
    }

    if (lowerMessage.contains('server is missing vbee_api_key')) {
      return 'Chua cau hinh VBEE_API_KEY tren Supabase secrets.';
    }

    if (lowerMessage.contains('server is missing vbee_voice_code')) {
      return 'Chua cau hinh voice Vbee cho ngon ngu nay.';
    }

    if (lowerMessage.contains('api key not valid')) {
      return 'API key khong hop le. Hay tao key moi va cap nhat Supabase secrets.';
    }

    if (lowerMessage.contains('quota') ||
        lowerMessage.contains('rate limit') ||
        lowerMessage.contains('resource has been exhausted')) {
      return 'Dich vu AI/TTS dang vuot quota. Hay doi mot luc hoac nang cap quota.';
    }

    if (lowerMessage.contains('permission') ||
        lowerMessage.contains('not enabled') ||
        lowerMessage.contains('forbidden')) {
      return 'API chua duoc bat hoac project khong du quyen truy cap.';
    }

    if (lowerMessage.contains('invalid json body')) {
      return 'Request translate gui len server khong hop le.';
    }

    return rawMessage;
  }
}
