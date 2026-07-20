import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const Map<String, String> expectedVietnamese = <String, String>{
    // Trip Planner.
    'Generating...': 'Đang tạo lịch trình...',
    'Saving…': 'Đang lưu…',
    'Share': 'Chia sẻ',
    'Share to Forum': 'Chia sẻ lên Diễn đàn',
    'Get Directions': 'Chỉ đường',
    'Create Trip on Google Maps': 'Tạo chuyến đi trên Google Maps',
    'Back to trip planner': 'Quay lại Lịch trình',
    'Trip saved!': 'Đã lưu chuyến đi!',
    'Shared to Forum!': 'Đã chia sẻ lên Diễn đàn!',

    // Loyalty Rewards.
    'Available points': 'Điểm hiện có',
    'Tokens': 'Token',
    'Lifetime points': 'Tổng điểm tích lũy',
    'Loyalty notifications': 'Thông báo điểm thưởng',
    'Only affects points and rewards notifications.':
        'Chỉ áp dụng cho thông báo về điểm và phần thưởng.',
    'Tier progress': 'Tiến trình xếp hạng',
    'Earn points': 'Kiếm điểm',
    'Add item to wishlist': 'Thêm mục vào danh sách yêu thích',
    'Create a forum post': 'Tạo bài viết trên diễn đàn',
    'Submit a review': 'Gửi đánh giá',
    'Check in at a place': 'Check-in tại một địa điểm',
    'Daily login': 'Đăng nhập hằng ngày',
    'Go': 'Đi',
    'Auto': 'Tự động',
    'Redeem': 'Đổi',
    'Add loyalty for testing': 'Cộng điểm thưởng để kiểm thử',
    'Exchange points to tokens': 'Đổi điểm thành token',
    'Redeem vouchers': 'Đổi voucher',
    'Voucher wallet': 'Ví voucher',
    'Transaction history': 'Lịch sử giao dịch',
    'Load loyalty failed.': 'Không tải được điểm thưởng.',
    'Retry': 'Thử lại',

    // Wishlist.
    'Wishlist': 'Danh sách yêu thích',
    'Loading wishlist': 'Đang tải danh sách yêu thích',
    'Load wishlist failed.': 'Không tải được danh sách yêu thích.',
    'Sign in': 'Đăng nhập',
  };

  test('localizes requested flows in Vietnamese', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);

    expectedVietnamese.forEach((String english, String vietnamese) {
      expect(strings.ui(english), vietnamese, reason: english);
    });
  });

  test('preserves requested flow labels in English', () {
    final AppStrings strings = AppStrings.of(AppLanguage.english);

    for (final String english in expectedVietnamese.keys) {
      expect(strings.ui(english), english, reason: english);
    }
  });

  test('localizes dynamic Loyalty Rewards and Wishlist copy', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);

    expect(strings.loyaltyHighestTier('Hạng Vàng'), 'Hạng cao nhất: Hạng Vàng');
    expect(
      strings.loyaltyTierProgress(2155, 3500, 'Hạng Bạch kim'),
      '2155/3500 điểm hạng để đạt Hạng Bạch kim',
    );
    expect(
      strings.loyaltyEarnSummary(
        20,
        20,
        requiresApproval: true,
        automatic: false,
      ),
      '+20 điểm, +20 điểm hạng · Cần xét duyệt',
    );
    expect(strings.wishlistSavedCount(3), '3 mục đã lưu');
  });
}
