import 'package:hellovietnam/core/network/edge_function_client.dart';
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
    Duration requestTimeout = const Duration(seconds: 20),
    EdgeFunctionClient? edgeFunctionClient,
  }) : _edgeFunctionClient =
           edgeFunctionClient ??
           EdgeFunctionClient(
             client: client,
             accessTokenProvider: accessTokenProvider ?? _currentAccessToken,
             requestTimeout: requestTimeout,
           );

  final EdgeFunctionClient _edgeFunctionClient;

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
      final Map<String, dynamic> data = await _edgeFunctionClient.postJson(
        'translate',
        requireAuth: true,
        body: <String, String>{
          'action': 'translate',
          'text': trimmedText,
          'sourceLanguageCode': sourceLanguageCode,
          'targetLanguageCode': targetLanguageCode,
          'targetLanguageName': targetLanguageName,
        },
      );
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
    } on EdgeFunctionException catch (error) {
      throw TranslationException(_mapServerError(error.message));
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
      final Map<String, dynamic> data = await _edgeFunctionClient.postJson(
        'translate',
        requireAuth: true,
        body: <String, String>{
          'action': 'tts',
          'text': trimmedText,
          'languageCode': languageCode,
          'languageName': languageName,
        },
      );
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
    } on EdgeFunctionException catch (error) {
      throw TranslationException(_mapServerError(error.message));
    } on TranslationException {
      rethrow;
    } catch (error) {
      throw TranslationException(_mapServerError(error.toString()));
    }
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

    if (lowerMessage.contains('please sign in')) {
      return 'Please sign in before using online translation.';
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

    if (lowerMessage.contains('timeoutexception') ||
        lowerMessage.contains('timed out')) {
      return 'Translate service timed out. Please try again.';
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
