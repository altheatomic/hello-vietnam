import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const expected = <String, String>{
    'What to eat nearby?': 'Ä‚n gÃ¬ gáº§n Ä‘Ã¢y?',
    'Explore restaurants near': 'KhÃ¡m phÃ¡ quÃ¡n Äƒn vÃ  nhÃ  hÃ ng quanh',
    'View restaurants on Google Maps': 'Xem quÃ¡n Äƒn trÃªn Google Maps',
    'Restaurant search is unavailable for this location.':
        'KhÃ´ng thá»ƒ tÃ¬m quÃ¡n Äƒn cho vá»‹ trÃ­ nÃ y.',
    'Could not open Google Maps. Please try again.':
        'KhÃ´ng thá»ƒ má»Ÿ Google Maps. Vui lÃ²ng thá»­ láº¡i.',
  };

  test('localizes nearby lunch discovery copy', () {
    final vi = AppStrings.of(AppLanguage.vietnamese);
    final en = AppStrings.of(AppLanguage.english);
    expected.forEach((english, vietnamese) {
      expect(vi.ui(english), vietnamese);
      expect(en.ui(english), english);
    });
  });
}
