import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const Map<String, String> expectedVietnamese = <String, String>{
    'AI Travel Assistant': 'Trợ lý du lịch AI',
    'Chat history': 'Lịch sử trò chuyện',
    'How can I help with your Vietnam trip?':
        'Tôi có thể giúp gì cho chuyến đi Việt Nam của bạn?',
    'Ask about your trip in Vietnam...': 'Hỏi về chuyến đi Việt Nam của bạn...',
    'Send': 'Gửi',
    'Listen': 'Nghe',
    'Try again': 'Thử lại',
    'AI chat history': 'Lịch sử trò chuyện AI',
    'Delete conversation?': 'Xóa cuộc trò chuyện?',
    'No conversations yet': 'Chưa có cuộc trò chuyện',
    'Open AI Travel Assistant': 'Mở Trợ lý du lịch AI',
    'Premium AI Travel Assistant': 'Trợ lý du lịch AI Premium',
    'Open Trip Planner': 'Mở trình lập lịch trình',
    'Open Translate': 'Mở công cụ dịch',
    'Explore Vietnam': 'Khám phá Việt Nam',
  };

  test('localizes AI chat labels in Vietnamese', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);

    expectedVietnamese.forEach((String english, String vietnamese) {
      expect(strings.ui(english), vietnamese, reason: english);
    });
  });

  test('preserves AI chat labels in English', () {
    final AppStrings strings = AppStrings.of(AppLanguage.english);

    for (final String english in expectedVietnamese.keys) {
      expect(strings.ui(english), english, reason: english);
    }
  });
}
