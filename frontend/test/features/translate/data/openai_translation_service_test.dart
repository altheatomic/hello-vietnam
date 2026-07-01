import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/features/translate/data/openai_translation_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('translate sends the signed-in user access token', () async {
    http.Request? capturedRequest;
    final service = OpenAITranslationService(
      accessTokenProvider: () async => 'user-jwt',
      client: MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'translation': 'xin chao',
            'detected_source_language_code': 'en',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.translate(
      text: 'hello',
      sourceLanguageCode: 'en',
      targetLanguageCode: 'vi',
      targetLanguageName: 'Vietnamese',
    );

    expect(result.translatedText, 'xin chao');
    expect(capturedRequest?.headers['Authorization'], 'Bearer user-jwt');
    expect(capturedRequest?.headers['apikey'], Env.supabaseAnonKey);
  });

  test('synthesizeSpeech returns the online TTS audio url', () async {
    final service = OpenAITranslationService(
      accessTokenProvider: () async => 'user-jwt',
      client: MockClient((http.Request request) async {
        expect(request.url.path, endsWith('/functions/v1/translate'));
        expect(request.headers['Authorization'], 'Bearer user-jwt');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'tts');
        expect(body['text'], 'xin chao');
        expect(body['languageCode'], 'vi');
        return http.Response(
          jsonEncode(<String, Object?>{
            'audio_url': 'https://cdn.example.com/speech.mp3',
            'provider': 'vbee',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.synthesizeSpeech(
      text: 'xin chao',
      languageCode: 'vi',
      languageName: 'Vietnamese',
    );

    expect(result.audioUrl, 'https://cdn.example.com/speech.mp3');
    expect(result.provider, 'vbee');
  });
}
