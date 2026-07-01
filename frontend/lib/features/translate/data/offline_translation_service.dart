import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class OfflineTranslationService {
  OfflineTranslationService._();

  static final OfflineTranslationService instance = OfflineTranslationService._();

  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();
  
  // Cache translators
  final Map<String, OnDeviceTranslator> _translators = <String, OnDeviceTranslator>{};

  TranslateLanguage _getLanguageCode(String code) {
    // Basic mapping, ML Kit supports BCP-47 tags natively but we map common ones
    switch (code.toLowerCase()) {
      case 'vi':
        return TranslateLanguage.vietnamese;
      case 'en':
      default:
        return TranslateLanguage.english;
    }
  }

  Future<bool> isModelDownloaded(String langCode) async {
    final TranslateLanguage language = _getLanguageCode(langCode);
    return _modelManager.isModelDownloaded(language.bcpCode);
  }

  Future<bool> downloadModel(String langCode) async {
    final TranslateLanguage language = _getLanguageCode(langCode);
    return _modelManager.downloadModel(language.bcpCode);
  }

  Future<String> translate(String text, String sourceLang, String targetLang) async {
    final TranslateLanguage source = _getLanguageCode(sourceLang);
    final TranslateLanguage target = _getLanguageCode(targetLang);

    final String key = '${source.bcpCode}_${target.bcpCode}';
    
    if (!_translators.containsKey(key)) {
      _translators[key] = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );
    }

    final OnDeviceTranslator translator = _translators[key]!;
    return translator.translateText(text);
  }
  
  void dispose() {
    for (final OnDeviceTranslator translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
  }
}
