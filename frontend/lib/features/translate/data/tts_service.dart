import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  static const String _googleTtsEngine = 'com.google.android.tts';

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;

    await _preferGoogleEngine();
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.46);
    await _flutterTts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<bool> speak(String text, {String languageCode = 'vi-VN'}) async {
    final String value = text.trim();
    if (value.isEmpty) return false;

    await _init();
    final String locale = _localeFor(languageCode);
    if (!await _isLanguageAvailable(locale)) {
      _log('Language not available: $locale');
      return false;
    }

    final dynamic languageResult = await _flutterTts.setLanguage(locale);
    _log('setLanguage($locale) -> $languageResult');
    final String? voiceName = await _setBestVoice(locale);
    _log('speak locale=$locale voice=${voiceName ?? 'default'} text="$value"');
    await _flutterTts.speak(value);
    return true;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> _preferGoogleEngine() async {
    try {
      final dynamic engines = await _flutterTts.getEngines;
      final bool hasGoogleEngine =
          engines is List && engines.contains(_googleTtsEngine);
      final dynamic defaultEngine = await _flutterTts.getDefaultEngine;
      _log('engines=$engines defaultEngine=$defaultEngine');
      if (defaultEngine == _googleTtsEngine) return;

      if (!hasGoogleEngine) {
        _log('Google TTS engine is not visible; trying direct setEngine.');
      }
      await _flutterTts.setEngine(_googleTtsEngine);
      _log('setEngine($_googleTtsEngine)');

      final dynamic nextDefaultEngine = await _flutterTts.getDefaultEngine;
      final dynamic nextEngines = await _flutterTts.getEngines;
      _log(
        'after setEngine engines=$nextEngines defaultEngine=$nextDefaultEngine',
      );
    } catch (error) {
      _log('setEngine skipped: $error');
    }
  }

  Future<bool> _isLanguageAvailable(String locale) async {
    final dynamic result = await _flutterTts.isLanguageAvailable(locale);
    if (result is bool) return result;
    if (result is String) return result.toLowerCase() == 'true';
    if (result is int) return result == 1;
    return false;
  }

  Future<String?> _setBestVoice(String locale) async {
    try {
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is! List) return null;

      final String language = locale.split('-').first.toLowerCase();
      Map<String, String>? fallbackVoice;
      for (final dynamic rawVoice in rawVoices) {
        if (rawVoice is! Map) continue;
        final String? voiceName = _readVoiceValue(rawVoice, 'name');
        final String? voiceLocale = _readVoiceValue(rawVoice, 'locale');
        if (voiceName == null || voiceLocale == null) continue;

        final Map<String, String> voice = <String, String>{
          'name': voiceName,
          'locale': voiceLocale,
        };
        final String normalizedVoiceLocale = voiceLocale.replaceAll('_', '-');
        if (normalizedVoiceLocale.toLowerCase() == locale.toLowerCase()) {
          await _flutterTts.setVoice(voice);
          return voiceName;
        }
        if (fallbackVoice == null &&
            normalizedVoiceLocale.toLowerCase().startsWith('$language-')) {
          fallbackVoice = voice;
        }
      }

      if (fallbackVoice != null) {
        await _flutterTts.setVoice(fallbackVoice);
        return fallbackVoice['name'];
      }
    } catch (_) {
      // Some engines reject voice selection even when setLanguage works.
    }
    return null;
  }

  String? _readVoiceValue(Map<dynamic, dynamic> voice, String key) {
    final dynamic value = voice[key];
    return value?.toString();
  }

  String _localeFor(String languageCode) {
    final String code = languageCode.replaceAll('_', '-').trim();
    if (code.contains('-')) return code;

    switch (code.toLowerCase()) {
      case 'vi':
        return 'vi-VN';
      case 'en':
        return 'en-US';
      case 'zh':
        return 'zh-CN';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'es':
        return 'es-ES';
      case 'it':
        return 'it-IT';
      case 'pt':
        return 'pt-PT';
      default:
        return code;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('TtsService: $message');
    }
  }
}
