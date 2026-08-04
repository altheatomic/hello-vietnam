import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const expected = <String, String>{
    'What to eat nearby?': 'Ăn gì gần đây?',
    'Explore restaurants near': 'Khám phá quán ăn và nhà hàng quanh',
    'View restaurants on Google Maps': 'Xem quán ăn trên Google Maps',
    'Restaurant search is unavailable for this location.':
        'Không thể tìm quán ăn cho vị trí này.',
    'Could not open Google Maps. Please try again.':
        'Không thể mở Google Maps. Vui lòng thử lại.',
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
