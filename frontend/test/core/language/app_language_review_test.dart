import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  test('localizes review labels in Vietnamese', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);

    expect(strings.ui('Write a review'), 'Viết đánh giá');
    expect(strings.ui('Edit your review'), 'Sửa đánh giá của bạn');
    expect(strings.ui('Publish review'), 'Đăng đánh giá');
    expect(
      strings.ui('Share what stood out for you...'),
      'Chia sẻ điều khiến bạn ấn tượng...',
    );
    expect(strings.reviewCount(12), '12 đánh giá');
    expect(strings.reviewRatingFilterLabel(5), '5 sao');
    expect(strings.reviewBreakdownStarLabel(1), '1 sao');
    expect(
      strings.noReviewsYetFor('Hải Phòng'),
      'Chưa có đánh giá nào cho Hải Phòng.',
    );
    expect(strings.reviewSummaryLabel(4.8), 'Tuyệt vời');
    expect(strings.reviewSummaryLabel(0), 'Chưa có xếp hạng');
    expect(strings.ui('Recommended season'), 'Mùa gợi ý');
    expect(strings.ui('Location'), 'Vị trí');
    expect(strings.ui('Ingredients'), 'Nguyên liệu');
    expect(
      strings.ui('The highlights of a visit'),
      'Điểm nổi bật khi ghé thăm',
    );
    expect(strings.ui('All Category'), 'Tất cả danh mục');
    expect(strings.ui('Destination'), 'Điểm đến');
  });
}
