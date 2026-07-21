import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  test('localizes saved trips labels in Vietnamese', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);

    expect(strings.ui('Saved Trips'), 'Chuyến đi đã lưu');
    expect(strings.savedItinerariesCount(3), '3 lịch trình đã lưu');
    expect(
      strings.savedPlacesWaiting(5),
      '5 điểm vẫn đang chờ đánh dấu hoàn thành.',
    );
    expect(strings.ui('In Progress'), 'Đang đi');
    expect(strings.ui('April 2026'), 'Tháng 4 2026');
    expect(strings.ui('16 Apr • 3 days 2 nights'), '16 Thg 4 • 3 ngày 2 đêm');
    expect(strings.savedTripCompletedCount(1, 3), '1/3 hoàn thành');
    expect(
      strings.savedTripRemainingPlaces(2),
      '2 điểm còn lại để hoàn thành chuyến đi này.',
    );
  });
}
