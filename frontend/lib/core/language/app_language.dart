import 'package:flutter/material.dart';

import '../storage/local_storage.dart';

enum AppLanguage {
  english('en', 'English', 'English', 'gb'),
  vietnamese('vi', 'Tiếng Việt', 'Vietnamese', 'vn');

  const AppLanguage(
    this.code,
    this.nativeName,
    this.englishName,
    this.flagCode,
  );

  final String code;
  final String nativeName;
  final String englishName;
  final String flagCode;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (AppLanguage language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();

  static final AppLanguageController instance = AppLanguageController._();
  static const String _storageKey = 'app_language_code';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  String get languageCode => _language.code;
  Locale get locale => _language.locale;

  Future<void> initialize() async {
    final String? storedCode = LocalStorage.instance.getString(_storageKey);
    _language = AppLanguage.fromCode(storedCode);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    await LocalStorage.instance.setString(_storageKey, language.code);
    _language = language;
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final AppLanguageScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return scope?.notifier ?? AppLanguageController.instance;
  }

  static AppLanguage languageOf(BuildContext context) =>
      controllerOf(context).language;
}

extension AppLanguageBuildContext on BuildContext {
  AppLanguageController get languageController =>
      AppLanguageScope.controllerOf(this);

  AppStrings get l10n => AppStrings.of(AppLanguageScope.languageOf(this));
}

class AppStrings {
  const AppStrings._(this.appLanguage);

  final AppLanguage appLanguage;

  static AppStrings of(AppLanguage language) => AppStrings._(language);

  bool get _vi => appLanguage == AppLanguage.vietnamese;

  String get appName => 'Hello Vietnam';
  String get home => _vi ? 'Trang chủ' : 'Home';
  String get tripPlanner => _vi ? 'Lịch trình' : 'Trip Planner';
  String get forum => _vi ? 'Diễn đàn' : 'Forum';
  String get profile => _vi ? 'Hồ sơ' : 'Profile';
  String get translate => _vi ? 'Dịch' : 'Translate';
  String get sendReport => _vi ? 'Báo lỗi' : 'Send Report';
  String get recommend => _vi ? 'Gợi ý' : 'Recommend';
  String get explore => _vi ? 'Khám phá' : 'Explore';
  String get popularApps => _vi ? 'Ứng dụng' : 'Popular Apps';
  String get aiSearch => 'AI Search';
  String get searchDestinations =>
      _vi ? 'Tìm điểm đến' : 'Search for destinations';
  String get retune => _vi ? 'Chỉnh lại' : 'Retune';
  String get pickedForYou => _vi ? 'Dành cho bạn' : 'Picked For You';
  String get bestDestination => _vi ? 'Điểm đến nổi bật' : 'Best Destination';
  String get bestDishes => _vi ? 'Món ngon nổi bật' : 'Best Dishes';
  String get exploreTunedTitle =>
      _vi ? 'Khám phá theo gu' : 'Explore, tuned to you';
  String get exploreTunedDescription => _vi
      ? 'Các chủ đề bạn thích được ưu tiên để món ăn, văn hóa, địa điểm và hoạt động hợp gu hơn.'
      : 'We moved your preferred themes closer to the top so food, culture, places, and activities feel more personal from the first scroll.';

  String get myProfile => _vi ? 'Hồ sơ của tôi' : 'My Profile';
  String get upgradeAccount => _vi ? 'Nâng cấp tài khoản' : 'Upgrade Account';
  String get changePassword => _vi ? 'Đổi mật khẩu' : 'Change Password';
  String get wishlist => _vi ? 'Danh sách yêu thích' : 'Wishlist';
  String get voucher => _vi ? 'Mã ưu đãi' : 'Voucher';
  String get language => _vi ? 'Ngôn ngữ' : 'Language';
  String get currency => _vi ? 'Tiền tệ' : 'Currency';
  String get notification => _vi ? 'Thông báo' : 'Notification';
  String get deleteUserData =>
      _vi ? 'Quản lý media đã tải lên' : 'Manage uploaded media';
  String get logOut => _vi ? 'Đăng xuất' : 'Log out';

  String get selectPreferredLanguage =>
      _vi ? 'Chọn ngôn ngữ bạn muốn sử dụng' : 'Select your preferred language';
  String get currentLanguage => _vi ? 'Ngôn ngữ hiện tại' : 'Current language';
  String get appInterfaceLanguage =>
      _vi ? 'Ngôn ngữ giao diện ứng dụng' : 'App interface language';
  String get applyingLanguage =>
      _vi ? 'Đang áp dụng ngôn ngữ...' : 'Applying language...';
  String get languageUpdated =>
      _vi ? 'Đã cập nhật ngôn ngữ' : 'Language updated';
  String get languageUpdateFailed => _vi
      ? 'Không thể cập nhật ngôn ngữ. Vui lòng thử lại.'
      : 'Could not update language. Please try again.';
  String get upcomingTrip => _vi ? 'Sắp đi' : 'Upcoming Trip';
  String get activeTrip => _vi ? 'Đang đi' : 'Active Trip';
  String get tripCompleted => _vi ? 'Đã hoàn tất' : 'Trip Completed';
  String dayOf(int day, int totalDays) =>
      _vi ? 'Ngày $day/$totalDays' : 'Day $day of $totalDays';
  String stepOf(int step, int totalSteps) =>
      _vi ? 'Bước $step/$totalSteps' : 'Step $step of $totalSteps';
  String savedTripUpdated(String title) => _vi
      ? '$title đã được cập nhật trong Chuyến đi đã lưu'
      : '$title updated in Saved Trips';
  String redeemPointsConfirm(String points, String title) => _vi
      ? 'Đổi $points điểm để nhận "$title"?'
      : 'Redeem $points points for "$title"?';
  String expiryDate(String date) =>
      _vi ? 'Ngày hết hạn: $date' : 'Expiry date: $date';
  String needMorePoints(String points) =>
      _vi ? 'Bạn cần thêm $points điểm' : 'You need $points more points';
  String routingTo(String placeTitle) =>
      _vi ? 'Đang chỉ đường đến $placeTitle' : 'Routing to $placeTitle';
  String applyFilters(int count) =>
      _vi ? 'Áp dụng bộ lọc ($count)' : 'Apply Filters ($count)';
  String earnedLoyaltyPoints(String points) => _vi
      ? 'Bạn đã nhận được $points điểm thưởng'
      : 'You earned $points loyalty points';
  String rewardHistoryAdded(String actionLabel) => _vi
      ? '$actionLabel đã được thêm vào lịch sử điểm thưởng.'
      : '$actionLabel has been added to your rewards history.';
  String validForDays(int days) => _vi
      ? 'Có hiệu lực trong $days ngày kể từ ngày đổi'
      : 'Valid for $days days from redemption date';
  String justPrice(String price) => _vi ? 'Chỉ $price \$' : 'Just $price \$';
  String currentPlan(String plan) =>
      _vi ? 'Gói hiện tại: $plan' : 'Current plan: $plan';
  String daysDone(int days) => _vi ? '$days ngày xong' : '$days days done';
  String get firstStop => _vi ? 'Điểm đầu' : 'First stop';
  String get nextStop => _vi ? 'Điểm tiếp' : 'Next stop';
  String activitiesCompleted(int count, int days) => _vi
      ? '$count hoạt động xong · $days ngày'
      : '$count activities completed · $days days';
  String savedItinerariesCount(int count) =>
      _vi ? '$count lịch trình đã lưu' : '$count saved itineraries';
  String savedPlacesWaiting(int count) => _vi
      ? '$count điểm vẫn đang chờ đánh dấu hoàn thành.'
      : '$count places still waiting to be checked off.';
  String savedTripGroupCount(int count) =>
      _vi ? '$count chuyến đi' : '$count trips';
  String savedTripCompletedCount(int completed, int total) =>
      _vi ? '$completed/$total hoàn thành' : '$completed/$total completed';
  String savedTripRemainingPlaces(int count) => _vi
      ? '$count điểm còn lại để hoàn thành chuyến đi này.'
      : '$count places left to complete on this trip.';
  String reviewCount(int count) => _vi ? '$count đánh giá' : '$count reviews';
  String reviewRatingFilterLabel(int star) => _vi ? '$star sao' : '$star-star';
  String reviewBreakdownStarLabel(int star) => _vi ? '$star sao' : '$star star';
  String noReviewsYetFor(String title) =>
      _vi ? 'Chưa có đánh giá nào cho $title.' : 'No reviews yet for $title.';
  String reviewSummaryLabel(double rating) {
    if (rating >= 4.7) return _vi ? 'Tuyệt vời' : 'Fantastic';
    if (rating >= 4.3) return _vi ? 'Rất tốt' : 'Great';
    if (rating >= 3.5) return _vi ? 'Tốt' : 'Good';
    if (rating > 0) return _vi ? 'Ổn' : 'Fair';
    return _vi ? 'Chưa có xếp hạng' : 'No ratings yet';
  }

  String forumPostsCount(int count) => _vi ? '$count bài viết' : '$count posts';
  String wishlistSavedCount(int count) => _vi
      ? '$count mục đã lưu'
      : '$count saved ${count == 1 ? 'item' : 'items'}';
  String loyaltyHighestTier(String tier) =>
      _vi ? 'Hạng cao nhất: $tier' : 'Highest tier: $tier';
  String loyaltyTierProgress(int current, int target, String tier) => _vi
      ? '$current/$target điểm hạng để đạt $tier'
      : '$current/$target tier points to $tier';
  String get loyaltyHighestTierReached =>
      _vi ? 'Bạn đang ở hạng cao nhất.' : 'You are at the highest tier.';
  String loyaltyCycleEnds(String date) =>
      _vi ? 'Chu kỳ kết thúc: $date' : 'Cycle ends: $date';
  String loyaltyEarnSummary(
    int points,
    int tierPoints, {
    required bool requiresApproval,
    required bool automatic,
  }) {
    final String base = _vi
        ? '+$points điểm, +$tierPoints điểm hạng'
        : '+$points points, +$tierPoints tier points';
    final String suffix = requiresApproval
        ? (_vi ? ' · Cần xét duyệt' : ' . Needs review')
        : automatic
        ? (_vi ? ' · Tự động' : ' . Automatic')
        : '';
    return '$base$suffix';
  }

  String loyaltyTestPointsAdded(int points) => _vi
      ? 'Đã cộng $points điểm kiểm thử.'
      : 'Added $points test loyalty points.';
  String loyaltyTokenCost(int points, {int? dailyLimit}) {
    if (_vi) {
      return dailyLimit == null
          ? 'Chi phí: $points điểm.'
          : 'Chi phí: $points điểm. Giới hạn mỗi ngày: $dailyLimit token.';
    }
    return dailyLimit == null
        ? 'Cost: $points points.'
        : 'Cost: $points points. Daily limit: $dailyLimit tokens.';
  }

  String loyaltyVoucherRequirement(int points, String description) =>
      _vi ? '$points điểm · $description' : '$points points . $description';
  String loyaltyWalletExpiry(String date) =>
      _vi ? 'Hết hạn $date' : 'Expires $date';
  String loyaltyTransactionSummary(
    String status,
    int pointChange,
    int tokenChange,
    String? date,
  ) {
    final String points = pointChange == 0
        ? ''
        : ' ${pointChange > 0 ? '+' : ''}$pointChange ${_vi ? 'điểm' : 'pts'}';
    final String tokens = tokenChange == 0
        ? ''
        : ' ${tokenChange > 0 ? '+' : ''}$tokenChange token';
    final String dateSuffix = date == null
        ? ''
        : _vi
        ? ' · $date'
        : ' . $date';
    return '$status$points$tokens$dateSuffix';
  }

  String get cancel => _vi ? 'Hủy' : 'Cancel';
  String get viewPlan => _vi ? 'Xem lịch' : 'View Plan';
  String get endTrip => _vi ? 'Kết thúc' : 'End Trip';
  String get details => _vi ? 'Chi tiết' : 'Details';
  String get dismiss => _vi ? 'Ẩn' : 'Dismiss';

  String get retry => _vi ? 'Thử lại' : 'Retry';
  String get signIn => _vi ? 'Đăng nhập' : 'Sign in';
  String get allCategories => _vi ? 'Tất cả danh mục' : 'All Categories';
  String get loadWishlistFailed =>
      _vi ? 'Không tải được danh sách yêu thích.' : 'Load wishlist failed.';
  String get pleaseSignInToUseWishlist => _vi
      ? 'Vui lòng đăng nhập để dùng danh sách yêu thích.'
      : 'Please sign in to use wishlist.';

  String noItemInWishlist(String itemLabel) {
    return _vi
        ? 'Chưa có $itemLabel trong danh sách yêu thích.'
        : 'No ${itemLabel.toLowerCase()} in wishlist.';
  }

  String wishlistTypeLabel(String typeCode) {
    return switch (typeCode) {
      'city' => _vi ? 'Thành phố' : 'City',
      'food' => _vi ? 'Món ăn' : 'Food',
      'place' => _vi ? 'Địa điểm' : 'Place',
      'culture' => _vi ? 'Văn hóa' : 'Culture',
      'activity' => _vi ? 'Hoạt động' : 'Activity',
      'localProduct' => _vi ? 'Đặc sản địa phương' : 'Local product',
      'item' => _vi ? 'mục' : 'item',
      _ => _vi ? 'Mục' : 'Item',
    };
  }

  String exploreCategoryLabel(String id) {
    return switch (id) {
      'activities' => _vi ? 'Hoạt động' : 'Activities',
      'culture' => _vi ? 'Văn hóa' : 'Culture',
      'food' => _vi ? 'Ẩm thực' : 'Food',
      'local_products' => _vi ? 'Đặc sản' : 'Local Products',
      _ => id,
    };
  }

  String featureLabelForRoute(String route) {
    return switch (route) {
      '/trip-planner' => tripPlanner,
      '/forum' => forum,
      '/messages' => forum,
      '/translate' => translate,
      '/send-feedback' => sendReport,
      '/recommend' => recommend,
      '/recommend/where-search' => recommend,
      '/explore' => explore,
      '/popular-apps' => popularApps,
      '/ai-search' => aiSearch,
      _ => route,
    };
  }

  String ui(String english) {
    if (!_vi) return english;
    return _viText[english] ?? english;
  }

  static const Map<String, String> _viText = <String, String>{
    'Opening Hello Vietnam': 'Đang mở Hello Vietnam',
    'Preparing your Vietnam journey': 'Đang chuẩn bị hành trình Việt Nam',
    'Home': 'Trang chủ',
    'Planner': 'Lịch trình',
    'Saved': 'Đã lưu',
    'Forum': 'Diễn đàn',
    'Profile': 'Hồ sơ',
    'Explore Vietnam with': 'Khám phá Việt Nam cùng',
    'Explore local culture, traditional food, and meaningful travel experiences across Vietnam.\nLet us guide you through every journey.':
        'Khám phá văn hóa, ẩm thực và trải nghiệm du lịch khắp Việt Nam.\nĐể chúng tôi đồng hành cùng bạn.',
    'Get Started': 'Bắt đầu',
    'Discover': 'Khám phá',
    'Destination': 'Điểm đến',
    'Login to Start Your': 'Đăng nhập để bắt đầu',
    'Amazing Trips': 'Chuyến đi tuyệt vời',
    'Enter your email': 'Nhập email',
    'Enter your password': 'Nhập mật khẩu',
    'Enter your name': 'Nhập tên',
    'Confirm password': 'Xác nhận mật khẩu',
    'Enter your current password': 'Nhập mật khẩu hiện tại',
    'Enter your new password': 'Nhập mật khẩu mới',
    'Confirm your new password': 'Xác nhận mật khẩu mới',
    'Please enter your email': 'Vui lòng nhập email',
    'Please enter a valid email address': 'Email không hợp lệ',
    'Please fill in all fields': 'Vui lòng nhập đầy đủ thông tin',
    'Passwords do not match': 'Mật khẩu không khớp',
    'Remember me': 'Ghi nhớ',
    'Forgot Password?': 'Quên mật khẩu?',
    'Forgot password?': 'Quên mật khẩu?',
    'Continue': 'Tiếp tục',
    'Next': 'Tiếp tục',
    'Or': 'Hoặc',
    'Or login with': 'Hoặc đăng nhập bằng',
    'Sign in with Google': 'Đăng nhập với Google',
    'Continue with Google': 'Tiếp tục với Google',
    "Don't have an account? ": 'Chưa có tài khoản? ',
    'Create an account': 'Tạo tài khoản',
    'Create Account': 'Tạo tài khoản',
    'Sign Up to Explore': 'Đăng ký để khám phá',
    'Sign Up': 'Đăng ký',
    'Sign up': 'Đăng ký',
    'Already have an account? ': 'Đã có tài khoản? ',
    'Login': 'Đăng nhập',
    'Failed to sign in': 'Đăng nhập thất bại',
    'Google sign in failed': 'Đăng nhập Google thất bại',
    'Sign up failed': 'Đăng ký thất bại',
    'Success! Please check your email for a confirmation link.':
        'Thành công! Vui lòng kiểm tra email để xác nhận.',
    'Google Sign-In is handled in Login page':
        'Đăng nhập Google được thực hiện ở trang Đăng nhập',
    'Save': 'Lưu',
    'Edit Profile': 'Sửa hồ sơ',
    'Email': 'Email',
    'Username': 'Tên người dùng',
    'Upgrade Account': 'Nâng cấp tài khoản',
    'Upgrade account': 'Nâng cấp tài khoản',
    'Change Password': 'Đổi mật khẩu',
    'Change your password': 'Đổi mật khẩu của bạn',
    'Congratulations!': 'Hoàn tất!',
    'Your password has been changed': 'Mật khẩu đã được thay đổi',
    'New password and confirm password do not match':
        'Mật khẩu mới và xác nhận không khớp',
    'New password must be different from current password':
        'Mật khẩu mới phải khác mật khẩu hiện tại',
    'Back to Login': 'Về đăng nhập',
    'Create new password': 'Tạo mật khẩu mới',
    'Check your email': 'Kiểm tra email',
    'Reset Password': 'Đặt lại mật khẩu',
    'Please enter your email to receive\npassword reset link':
        'Nhập email để nhận\nliên kết đặt lại mật khẩu',
    'Confirm email': 'Xác nhận email',
    "We've sent a password reset link to\n":
        'Chúng tôi đã gửi liên kết đặt lại mật khẩu đến\n',
    '\n\n1. Click the link in your email\n2. You\'ll be redirected back here\n3. Click "I\'ve clicked the link" or "Refresh/Verify Session"':
        '\n\n1. Bấm liên kết trong email\n2. Bạn sẽ quay lại đây\n3. Bấm "Tôi đã bấm liên kết" hoặc "Kiểm tra phiên"',
    'I\'ve clicked the link': 'Tôi đã bấm liên kết',
    'Refresh/Verify Session': 'Kiểm tra phiên',
    'Didn\'t receive the email? ': 'Chưa nhận được email? ',
    'Resend': 'Gửi lại',
    'Create your new password': 'Tạo mật khẩu mới',
    'Your password has been created': 'Mật khẩu đã được tạo',
    'Send reset link': 'Gửi liên kết',
    'Resend email': 'Gửi lại email',
    'I clicked the link': 'Tôi đã bấm liên kết',
    'Verify session': 'Kiểm tra phiên',
    'Enter text to translate...': 'Nhập nội dung cần dịch...',
    'Search language...': 'Tìm ngôn ngữ...',
    'Translation': 'Bản dịch',
    'Translate': 'Dịch',
    'Clear': 'Xóa',
    'QUICK EXAMPLES': 'VÍ DỤ NHANH',
    'Listening...': 'Đang nghe...',
    'Translating...': 'Đang dịch...',
    'Translation appears here': 'Bản dịch sẽ hiện ở đây',
    'DONE': 'XONG',
    'Select Language': 'Chọn ngôn ngữ',
    'Auto detect': 'Tự nhận diện',
    'Vietnamese': 'Tiếng Việt',
    'English': 'Tiếng Anh',
    'Report an Issue': 'Báo lỗi',
    'Help us improve the app': 'Giúp chúng tôi cải thiện ứng dụng',
    'Issue type': 'Loại lỗi',
    'Incorrect data': 'Dữ liệu sai',
    'Missing information': 'Thiếu thông tin',
    'Inappropriate image/video': 'Ảnh/video không phù hợp',
    'Map/address issue': 'Lỗi bản đồ/địa chỉ',
    'Other': 'Khác',
    'Please select one': 'Vui lòng chọn một mục',
    'Description': 'Mô tả',
    'Image or video': 'Ảnh hoặc video',
    'Upload image or video': 'Tải ảnh hoặc video',
    'Please describe the issue you encountered so we can fix it as quickly as possible...':
        'Mô tả lỗi bạn gặp để chúng tôi có thể sửa nhanh nhất...',
    'e.g. "When I tap the Save button on screen X, the app crashes"':
        'VD: "Khi tôi bấm nút Lưu ở màn X, app bị thoát"',
    'Thank you for your report. Our team will review it as soon as possible.':
        'Cảm ơn báo cáo của bạn. Đội ngũ sẽ xem xét sớm nhất có thể.',
    'Cancel': 'Hủy',
    'Submitting...': 'Đang gửi...',
    'Submit Report': 'Gửi báo lỗi',
    'Report Submitted!': 'Đã gửi báo lỗi!',
    'Thank you for your feedback.': 'Cảm ơn phản hồi của bạn.',
    'Our team will review it and get back to you as soon as possible.':
        'Đội ngũ sẽ xem xét và phản hồi sớm nhất có thể.',
    'Done': 'Xong',
    'Messages': 'Tin nhắn',
    'Create post': 'Tạo bài viết',
    'Post': 'Bài viết',
    'What do you want to share?': 'Bạn muốn chia sẻ gì?',
    'Saved Posts': 'Bài đã lưu',
    'Posts': 'Bài viết',
    'Followers': 'Người theo dõi',
    'For you': 'Dành cho bạn',
    'No saved posts yet': 'Chưa có bài đã lưu',
    'Loading profile': 'Đang tải hồ sơ',
    'Profile not found': 'Không tìm thấy hồ sơ',
    'Loading post': 'Đang tải bài viết',
    'Popular answers': 'Câu trả lời nổi bật',
    'Report Post': 'Báo cáo bài viết',
    'Post not found': 'Không tìm thấy bài viết',
    'Report submitted. We will review it anonymously.':
        'Đã gửi báo cáo. Chúng tôi sẽ xem xét ẩn danh.',
    'Go back': 'Quay lại',
    'Follow': 'Theo dõi',
    'Following': 'Đang theo dõi',
    'Type your answer': 'Nhập câu trả lời',
    'Clear All': 'Xóa tất cả',
    'Filters': 'Bộ lọc',
    'Notification type': 'Loại thông báo',
    'Loading notifications': 'Đang tải thông báo',
    'Unable to load notifications right now.': 'Hiện chưa tải được thông báo.',
    'No Notifications': 'Chưa có thông báo',
    "We'll let you know when there will be\nsomething to update you.":
        'Chúng tôi sẽ báo cho bạn khi có\nnội dung mới cần cập nhật.',
    'ALL': 'TẤT CẢ',
    'TRIP': 'CHUYẾN ĐI',
    'FORUM': 'DIỄN ĐÀN',
    'VOUCHER': 'ƯU ĐÃI',
    'ACCOUNT': 'TÀI KHOẢN',
    'All notifications were cleared': 'Đã xóa tất cả thông báo',
    "Da Lat's got new festival!": 'Đà Lạt có lễ hội mới!',
    "Don't miss the chance to go to the Flower Festival.":
        'Đừng bỏ lỡ cơ hội tham gia Lễ hội Hoa.',
    'You got new replies': 'Bạn có phản hồi mới',
    'Brandon has just commented on your post':
        'Brandon vừa bình luận bài viết của bạn',
    'Fresh Flavors Unveiled!': 'Hương vị mới đã ra mắt!',
    'New menu items are in! What will you try next?':
        'Món mới đã có rồi! Bạn muốn thử món nào tiếp theo?',
    'How was your trips?': 'Chuyến đi của bạn thế nào?',
    'Tell us how satisfied you are on your 3-days trips in Ho Chi Minh City!!':
        'Hãy cho chúng tôi biết mức độ hài lòng của bạn về chuyến đi 3 ngày tại TP. Hồ Chí Minh!',
    'You got a new voucher!!': 'Bạn có voucher mới!',
    'Get 10% off on for your premium subscription':
        'Giảm 10% cho gói Premium của bạn',
    'Your April getaway is ready': 'Kỳ nghỉ tháng 4 đã sẵn sàng',
    'We found destination suggestions that fit your travel dates.':
        'Chúng tôi đã tìm thấy gợi ý điểm đến phù hợp với ngày đi của bạn.',
    'You are close to Silver rank': 'Bạn sắp đạt hạng Bạc',
    'Check your benefits to unlock more vouchers and travel perks.':
        'Kiểm tra quyền lợi để mở thêm voucher và ưu đãi du lịch.',
    '9 days ago': '9 ngày trước',
    '13 days ago': '13 ngày trước',
    '4 days ago': '4 ngày trước',
    '1 week ago': '1 tuần trước',
    '11 days ago': '11 ngày trước',
    '2 days ago': '2 ngày trước',
    '6 hours ago': '6 giờ trước',
    'Just now': 'Vừa xong',
    'Dark theme': 'Giao diện tối',
    'Popular Apps': 'Ứng dụng',
    'App not found': 'Không tìm thấy ứng dụng',
    'Payment confirmed': 'Đã xác nhận thanh toán',
    'Your premium subscription is active.': 'Gói Premium đã được kích hoạt.',
    'Premium Account': 'Tài khoản Premium',
    'Premium Account Privileges': 'Quyền lợi tài khoản Premium',
    'Select your plan:': 'Chọn gói của bạn:',
    'Free': 'Miễn phí',
    'Current plan': 'Gói hiện tại',
    '1 Month': '1 tháng',
    '6 Months': '6 tháng',
    '12 Months': '12 tháng',
    'POPULAR': 'PHỔ BIẾN',
    "What you'll get:": 'Bạn sẽ nhận được:',
    '+ 2 more benefits': '+ 2 quyền lợi khác',
    'Access to AI Object Identification': 'Nhận diện vật thể bằng AI',
    'Practice Essential Vietnamese Phrases':
        'Luyện tập các câu tiếng Việt cần thiết',
    'Generate Personalized Itinerary': 'Tạo lịch trình cá nhân hóa',
    'Many more exclusive voucher & coupon':
        'Nhiều mã ưu đãi và coupon độc quyền hơn',
    'Paid': 'Đã thanh toán',
    'Voucher discount': 'Giảm giá voucher',
    'OK': 'OK',
    'Subtotal': 'Tạm tính',
    'Total': 'Tổng cộng',
    'Enter voucher code': 'Nhập mã voucher',
    'Select your payment method:': 'Chọn phương thức thanh toán:',
    'Premium subscription': 'Gói Premium',
    'Select or enter voucher code': 'Chọn hoặc nhập mã ưu đãi',
    'Remove': 'Xóa',
    'Add another payment method': 'Thêm phương thức thanh toán khác',
    'Select Voucher': 'Chọn mã ưu đãi',
    'Available Vouchers': 'Mã ưu đãi hiện có',
    'Or enter code manually': 'Hoặc nhập mã thủ công',
    'Apply': 'Áp dụng',
    'Active for 1 year': 'Có hiệu lực trong 1 năm',
    'Welcome Discount': 'Ưu đãi chào mừng',
    'Get \$2 off on your first premium subscription':
        'Giảm \$2 cho lần đăng ký Premium đầu tiên',
    '10% Off Premium': 'Giảm 10% Premium',
    'Save 10% on any premium plan': 'Tiết kiệm 10% cho mọi gói Premium',
    'Holiday Special': 'Ưu đãi mùa lễ',
    '15% off for holiday season': 'Giảm 15% cho mùa lễ',
    'Premium Max Saver': 'Tiết kiệm tối đa Premium',
    'Up to \$20 off premium plans from \$19.99':
        'Giảm đến \$20 cho gói Premium từ \$19.99',
    'Selected plan does not meet voucher minimum spend.':
        'Gói đã chọn chưa đạt giá trị tối thiểu của mã ưu đãi.',
    'Voucher applied:': 'Đã áp dụng mã:',
    'Min. purchase:': 'Đơn tối thiểu:',
    'Confirm Payment': 'Xác nhận thanh toán',
    'Secure Payment': 'Thanh toán bảo mật',
    'Review your purchase:': 'Kiểm tra đơn mua:',
    'Valid for': 'Có hiệu lực',
    'months': 'tháng',
    'Discount applied': 'Đã áp dụng giảm giá',
    'Total Amount': 'Tổng thanh toán',
    'Payment Method': 'Phương thức thanh toán',
    'Change': 'Đổi',
    'Important Information': 'Thông tin quan trọng',
    'Your subscription will automatically renew. You can cancel anytime from your account settings.':
        'Gói đăng ký sẽ tự động gia hạn. Bạn có thể hủy bất cứ lúc nào trong cài đặt tài khoản.',
    'I agree to the ': 'Tôi đồng ý với ',
    'Terms & Conditions': 'Điều khoản & Điều kiện',
    ' and ': ' và ',
    'Privacy Policy': 'Chính sách bảo mật',
    "✨ You're getting:": '✨ Bạn sẽ nhận được:',
    'AI Object Identification': 'Nhận diện vật thể bằng AI',
    'Vietnamese Phrases Practice': 'Luyện tập câu tiếng Việt',
    'Exclusive Vouchers': 'Mã ưu đãi độc quyền',
    'Processing...': 'Đang xử lý...',
    'Payment Successful! 🎉': 'Thanh toán thành công! 🎉',
    'Your premium subscription is now active':
        'Gói Premium của bạn đã được kích hoạt',
    'Transaction ID': 'Mã giao dịch',
    'Plan': 'Gói',
    'Amount Paid': 'Số tiền đã thanh toán',
    'Date': 'Ngày',
    'Valid Until': 'Có hiệu lực đến',
    'Premium Benefits Activated': 'Quyền lợi Premium đã kích hoạt',
    'Personalized Itinerary Generator': 'Tạo lịch trình cá nhân hóa',
    'Exclusive Vouchers & Coupons': 'Mã ưu đãi & coupon độc quyền',
    'Download Receipt': 'Tải biên lai',
    'Receipt download is coming soon.': 'Tính năng tải biên lai sẽ sớm có.',
    'Go to Home': 'Về trang chủ',
    'Reward': 'Phần thưởng',
    'Available Points': 'Điểm hiện có',
    'Use to redeem vouchers': 'Dùng để đổi mã ưu đãi',
    'View Benefits >': 'Xem quyền lợi >',
    'Gold': 'Hạng Vàng',
    'Gold Tier': 'Hạng Vàng',
    '45,000 / 70,000 pts': '45.000 / 70.000 điểm',
    '25,000 to Platinum': 'Còn 25.000 điểm đến Bạch kim',
    'Vouchers': 'Mã ưu đãi',
    'Redeem Voucher': 'Đổi mã ưu đãi',
    'My Vouchers (3)': 'Mã của tôi (3)',
    'Discount': 'Giảm giá',
    'Shipping': 'Vận chuyển',
    'Gift': 'Quà tặng',
    'Cashback': 'Hoàn tiền',
    'points': 'điểm',
    'Redeem Now': 'Đổi ngay',
    'Use Now': 'Dùng ngay',
    'Exp': 'HSD',
    'Voucher code copied': 'Đã sao chép mã ưu đãi',
    'Confirm Redemption': 'Xác nhận đổi mã',
    'Voucher Details': 'Chi tiết mã ưu đãi',
    'Voucher Code': 'Mã ưu đãi',
    'Copy': 'Sao chép',
    'Points required': 'Điểm cần đổi',
    'Your available points:': 'Điểm hiện có:',
    'Redeem Points': 'Đổi điểm',
    'Insufficient Points': 'Không đủ điểm',
    'How to Use': 'Cách sử dụng',
    'Copy the voucher code above': 'Sao chép mã ưu đãi phía trên',
    'Apply the code at checkout': 'Nhập mã khi thanh toán',
    'Enjoy your discount or benefit': 'Tận hưởng ưu đãi hoặc quyền lợi',
    'Code can only be used once before expiry date':
        'Mã chỉ dùng được một lần trước ngày hết hạn',
    'Important': 'Lưu ý',
    'This voucher cannot be exchanged for cash and is non-transferable. Please use before the expiration date.':
        'Mã ưu đãi không thể quy đổi thành tiền mặt và không thể chuyển nhượng. Vui lòng sử dụng trước ngày hết hạn.',
    '\$5 off on orders over \$20': 'Giảm \$5 cho đơn từ \$20',
    'Free nationwide shipping': 'Miễn phí vận chuyển toàn quốc',
    '\$10 off on orders over \$50': 'Giảm \$10 cho đơn từ \$50',
    'Free gift with purchase': 'Tặng quà khi mua hàng',
    '\$20 Premium voucher': 'Mã Premium trị giá \$20',
    '20% cashback up to 80K': 'Hoàn tiền 20% tối đa 80K',
    'Special discount voucher for orders valued at \$20 or more':
        'Mã giảm giá đặc biệt cho đơn hàng từ \$20 trở lên',
    'Valid for all products regardless of category':
        'Áp dụng cho mọi sản phẩm, không phân biệt danh mục',
    'Can be combined with free shipping voucher':
        'Có thể dùng cùng mã miễn phí vận chuyển',
    'Maximum discount of \$5 per order': 'Giảm tối đa \$5 mỗi đơn hàng',
    'Apply free delivery to eligible orders nationwide':
        'Áp dụng miễn phí giao hàng cho đơn đủ điều kiện trên toàn quốc',
    'No minimum order value required in selected zones':
        'Không yêu cầu giá trị đơn tối thiểu tại khu vực áp dụng',
    'Cannot be combined with another shipping voucher':
        'Không thể dùng cùng mã vận chuyển khác',
    'Special discount voucher for orders valued at \$50 or more':
        'Mã giảm giá đặc biệt cho đơn hàng từ \$50 trở lên',
    'Maximum discount of \$10 per order': 'Giảm tối đa \$10 mỗi đơn hàng',
    'Receive one surprise gift with qualifying purchase':
        'Nhận một phần quà bất ngờ khi đơn hàng đủ điều kiện',
    'Gift value may vary by campaign and stock':
        'Giá trị quà tặng có thể thay đổi theo chiến dịch và tồn kho',
    'Voucher can be redeemed once per account':
        'Mỗi tài khoản chỉ đổi được mã này một lần',
    'Premium voucher with \$20 discount for Premium package':
        'Mã giảm \$20 cho gói Premium',
    'Upgrade your experience with exclusive features':
        'Nâng cấp trải nghiệm với các tính năng độc quyền',
    '24/7 priority support from specialists':
        'Hỗ trợ ưu tiên 24/7 từ chuyên viên',
    'Many special benefits exclusively for Premium members':
        'Nhiều quyền lợi đặc biệt dành riêng cho thành viên Premium',
    'Can renew and accumulate more benefits':
        'Có thể gia hạn và tích lũy thêm quyền lợi',
    'Get 20% cashback on eligible orders (max 80K)':
        'Hoàn tiền 20% cho đơn đủ điều kiện (tối đa 80K)',
    'Cashback is credited within 24 hours after completion':
        'Tiền hoàn sẽ được cộng trong vòng 24 giờ sau khi hoàn tất',
    'Can be combined with selected platform offers':
        'Có thể dùng cùng một số ưu đãi được chọn trên nền tảng',
    'Spam': 'Spam',
    'Harassment or hate speech': 'Quấy rối hoặc thù ghét',
    'Inappropriate content': 'Nội dung không phù hợp',
    'False information': 'Thông tin sai lệch',
    'Violence or dangerous content': 'Bạo lực hoặc nguy hiểm',
    'Search destination': 'Tìm điểm đến',
    'Search destination...': 'Tìm điểm đến...',
    'Search destinations': 'Tìm điểm đến',
    'Recommendation': 'Gợi ý',
    'Please choose: ✨': 'Chọn nhé: ✨',
    'Popular Destinations': 'Điểm đến nổi bật',
    'Business Location': 'Địa điểm công việc',
    'Where will you be working?': 'Bạn sẽ làm việc ở đâu?',
    'e.g. District 1, Ho Chi Minh City': 'VD: Quận 1, TP. Hồ Chí Minh',
    'Choose your budget': 'Chọn ngân sách',
    'Pick one option below to continue': 'Chọn một mức để tiếp tục',
    'Generate': 'Tạo lịch trình',
    'e.g. 800,000 VND per day': 'VD: 800.000 VND/ngày',
    'Choose your travel dates': 'Chọn ngày đi',
    "When's your trip?": 'Chuyến đi của bạn vào khi nào?',
    'What is your interest?': 'Bạn thích gì?',
    'Select your preferences (multiple choices)': 'Chọn sở thích của bạn',
    'Culture & History': 'Văn hóa',
    'Nature & Outdoor': 'Thiên nhiên',
    'Adventure': 'Phiêu lưu',
    'Entertainment': 'Giải trí',
    'Leisure Trip': 'Du lịch',
    'Business Trip': 'Công tác',
    'Your Vietnam Adventure': 'Hành trình Việt Nam',
    'Personalized Itinerary': 'Lịch trình cá nhân hóa',
    "Let's create your perfect trip": 'Cùng tạo chuyến đi hoàn hảo của bạn',
    'Trip Type': 'Loại chuyến đi',
    'Saved Trips': 'Chuyến đi đã lưu',
    'Pick up where you left off and tick places as you complete them.':
        'Tiếp tục chuyến đi còn dang dở và đánh dấu các điểm đã hoàn thành.',
    'All': 'Tất cả',
    'Upcoming': 'Sắp đi',
    'In Progress': 'Đang đi',
    'Completed': 'Hoàn thành',
    'April 2026': 'Tháng 4 2026',
    'March 2026': 'Tháng 3 2026',
    'Leisure': 'Du lịch',
    '16 Apr • 3 days 2 nights': '16 Thg 4 • 3 ngày 2 đêm',
    '22 Apr • 2 days 1 night': '22 Thg 4 • 2 ngày 1 đêm',
    '28 Mar • 1 day': '28 Thg 3 • 1 ngày',
    '900,000 VND / day': '900.000 VND / ngày',
    '1,200,000 VND / day': '1.200.000 VND / ngày',
    'Standard range': 'Mức tiêu chuẩn',
    'Everything is still planned and ready to go.':
        'Mọi điểm vẫn đã được lên kế hoạch và sẵn sàng.',
    'All planned places are marked as completed.':
        'Tất cả điểm trong lịch trình đã được đánh dấu hoàn thành.',
    'Open itinerary': 'Mở lịch trình',
    'Plan again': 'Lên lịch lại',
    'No trips match this filter yet.': 'Chưa có chuyến đi nào khớp bộ lọc này.',
    'Try another filter or create a new itinerary from Trip Planner.':
        'Thử bộ lọc khác hoặc tạo lịch trình mới từ Lịch trình.',
    'Hoi An Heritage Escape': 'Hành trình di sản Hội An',
    'Da Lat Cool Weather Weekend': 'Cuối tuần mát lành Đà Lạt',
    'Hanoi Culture Sprint': 'Chuyến khám phá văn hóa Hà Nội',
    'Hoi An': 'Hội An',
    'Da Lat': 'Đà Lạt',
    'Hanoi': 'Hà Nội',
    'Japanese Covered Bridge': 'Chùa Cầu Nhật Bản',
    'Architecture and old town walk': 'Kiến trúc và dạo phố cổ',
    'Riverside Lunch Market': 'Chợ trưa ven sông',
    'Try cao lau and local desserts': 'Thử cao lầu và món ngọt địa phương',
    'Lantern Boat Ride': 'Đi thuyền ngắm đèn lồng',
    'Evening activity on Thu Bon River': 'Hoạt động buổi tối trên sông Thu Bồn',
    'Pine Hill Sunrise Spot': 'Điểm ngắm bình minh đồi thông',
    'Coffee stop with valley view': 'Dừng cà phê ngắm thung lũng',
    'Domaine de Marie Church': 'Nhà thờ Domaine de Marie',
    'Photo stop and short sightseeing': 'Chụp ảnh và tham quan nhanh',
    'Night Market Walk': 'Dạo chợ đêm',
    'Street food and souvenirs': 'Ẩm thực đường phố và quà lưu niệm',
    'Temple of Literature': 'Văn Miếu',
    'Morning cultural visit': 'Tham quan văn hóa buổi sáng',
    'Old Quarter Food Tour': 'Tour ẩm thực phố cổ',
    'Lunch tasting route': 'Tuyến ăn trưa trải nghiệm',
    'Hoan Kiem Lake': 'Hồ Hoàn Kiếm',
    'Late afternoon walk': 'Dạo bộ cuối chiều',
    'Enter address': 'Nhập địa chỉ',
    'We will suggest activities around your business location\nduring free time':
        'Chúng tôi sẽ gợi ý hoạt động gần nơi làm việc\ntrong thời gian rảnh',
    'Option 1: Enter daily budget': 'Cách 1: Nhập ngân sách/ngày',
    'Use an exact amount per day if you already know your spending limit.':
        'Dùng số tiền cụ thể nếu bạn đã biết giới hạn chi tiêu.',
    'Using exact daily budget. Price range will be ignored.':
        'Đang dùng ngân sách/ngày. Mức giá sẽ được bỏ qua.',
    'Option 2: Choose price range': 'Cách 2: Chọn mức giá',
    'Use a quick preset instead of typing an exact amount.':
        'Chọn nhanh một mức thay vì nhập số tiền cụ thể.',
    'Using price range. Typed daily budget will be ignored.':
        'Đang dùng mức giá. Ngân sách đã nhập sẽ được bỏ qua.',
    'OR': 'HOẶC',
    'Select your travel dates': 'Chọn ngày đi',
    'Pick dates': 'Chọn ngày',
    'Choose a start and end date': 'Chọn ngày bắt đầu và kết thúc',
    'day': 'ngày',
    'days': 'ngày',
    'January': 'Tháng 1',
    'February': 'Tháng 2',
    'March': 'Tháng 3',
    'April': 'Tháng 4',
    'May': 'Tháng 5',
    'June': 'Tháng 6',
    'July': 'Tháng 7',
    'August': 'Tháng 8',
    'September': 'Tháng 9',
    'October': 'Tháng 10',
    'November': 'Tháng 11',
    'December': 'Tháng 12',
    'Jan': 'Thg 1',
    'Feb': 'Thg 2',
    'Mar': 'Thg 3',
    'Apr': 'Thg 4',
    'Jun': 'Thg 6',
    'Jul': 'Thg 7',
    'Aug': 'Thg 8',
    'Sep': 'Thg 9',
    'Oct': 'Thg 10',
    'Nov': 'Thg 11',
    'Dec': 'Thg 12',
    'Su': 'CN',
    'Mo': 'T2',
    'Tu': 'T3',
    'We': 'T4',
    'Th': 'T5',
    'Fr': 'T6',
    'Sa': 'T7',
    'What kind of trips feel most like you?':
        'Kiểu chuyến đi nào hợp với bạn nhất?',
    'Choose a few directions so we can shape your first suggestions.':
        'Chọn vài hướng yêu thích để chúng tôi gợi ý phù hợp ngay từ đầu.',
    'Pick at least 2 travel styles.': 'Chọn ít nhất 2 phong cách du lịch.',
    'Who do you usually travel with?': 'Bạn thường đi cùng ai?',
    'This helps us avoid suggestions that feel awkward or impractical.':
        'Điều này giúp gợi ý thực tế và hợp hoàn cảnh hơn.',
    'Pick at least 1 companion style.': 'Chọn ít nhất 1 kiểu đồng hành.',
    'What budget feels comfortable?': 'Mức ngân sách nào phù hợp với bạn?',
    'We will tune recommendations so the app feels realistic from day one.':
        'Chúng tôi sẽ điều chỉnh gợi ý để app hữu ích ngay từ ngày đầu.',
    'Choose 1 budget level.': 'Chọn 1 mức ngân sách.',
    'How packed do you want your days to be?':
        'Bạn muốn lịch mỗi ngày dày đến mức nào?',
    'This controls whether we suggest slow days, balanced plans, or busier lists.':
        'Mục này quyết định app sẽ gợi ý lịch thư thả, cân bằng hay nhiều hoạt động hơn.',
    'Choose your preferred pace.': 'Chọn nhịp đi bạn muốn.',
    'Pick the things you want to see more often':
        'Chọn những điều bạn muốn thấy thường xuyên hơn',
    'This final step powers your Home and Explore suggestions right away.':
        'Bước cuối này sẽ cá nhân hóa gợi ý ở Trang chủ và Khám phá ngay.',
    'Pick at least 3 topics.': 'Chọn ít nhất 3 chủ đề.',
    'Back later': 'Để sau',
    'Saving...': 'Đang lưu...',
    'Finish': 'Hoàn tất',
    'Your Travel Taste': 'Gu du lịch của bạn',
    'You are telling us to prioritize': 'Bạn muốn chúng tôi ưu tiên',
    'Tailored to your travel taste': 'Gợi ý theo gu du lịch của bạn',
    'Refine': 'Chỉnh lại',
    'Food': 'Ẩm thực',
    'Culture': 'Văn hóa',
    'Nature': 'Thiên nhiên',
    'Relaxation': 'Thư giãn',
    'Shopping': 'Mua sắm',
    'Photography': 'Chụp ảnh',
    'Local Life': 'Đời sống địa phương',
    'Street food, specialties, local flavors':
        'Món đường phố, đặc sản, hương vị địa phương',
    'History, rituals, art, heritage': 'Lịch sử, nghi lễ, nghệ thuật, di sản',
    'Mountains, beaches, gardens, scenery':
        'Núi non, bãi biển, vườn cảnh, phong cảnh',
    'Easy pacing, cafes, spa, slow travel':
        'Nhịp đi thư thả, cà phê, spa, du lịch chậm',
    'Energetic activities and new thrills':
        'Hoạt động năng lượng và trải nghiệm mới',
    'Markets, crafts, local finds': 'Chợ, đồ thủ công, món hay ở địa phương',
    'Scenic spots and memorable visuals': 'Góc cảnh đẹp và khung hình đáng nhớ',
    'Neighborhood vibes and authentic moments':
        'Không khí khu phố và khoảnh khắc đời thường',
    'Solo': 'Đi một mình',
    'Couple': 'Cặp đôi',
    'Friends': 'Bạn bè',
    'Family': 'Gia đình',
    'Seniors': 'Người lớn tuổi',
    'Business': 'Công tác',
    'Freedom and flexible pacing': 'Tự do và linh hoạt nhịp đi',
    'Romantic and cozy suggestions': 'Gợi ý lãng mạn và ấm cúng',
    'Fun group-friendly experiences': 'Trải nghiệm vui, hợp đi nhóm',
    'Easy, safe, family-ready options': 'Lựa chọn dễ đi, an toàn, hợp gia đình',
    'Comfortable and low-effort plans': 'Kế hoạch thoải mái, ít tốn sức',
    'Efficient stops around a work trip':
        'Điểm ghé hiệu quả quanh chuyến công tác',
    'Affordable': 'Tiết kiệm',
    'Budget': 'Tiết kiệm',
    'Mid-range': 'Tầm trung',
    'Comfort': 'Thoải mái',
    'Standard': 'Tiêu chuẩn',
    'Premium': 'Cao cấp',
    'Smart spending and free gems': 'Chi tiêu thông minh và điểm miễn phí',
    'Balanced value and comfort': 'Cân bằng giữa giá trị và thoải mái',
    'More flexibility and polish': 'Linh hoạt hơn và chỉn chu hơn',
    'Top picks and upgraded stays': 'Lựa chọn cao cấp và lưu trú nâng hạng',
    'Easy': 'Nhẹ nhàng',
    'Balanced': 'Cân bằng',
    'Active': 'Năng động',
    'Packed': 'Dày lịch',
    'Slow mornings and room to breathe': 'Buổi sáng chậm rãi, có khoảng nghỉ',
    'A healthy mix of must-sees and rest':
        'Cân bằng giữa điểm phải đi và thời gian nghỉ',
    'More stops and more movement': 'Nhiều điểm dừng và di chuyển hơn',
    'Make the most of every hour': 'Tận dụng tối đa từng giờ',
    'Street Food': 'Ẩm thực đường phố',
    'Coffee': 'Cà phê',
    'Museums': 'Bảo tàng',
    'Temples': 'Đền chùa',
    'Festivals': 'Lễ hội',
    'Beaches': 'Bãi biển',
    'Mountains': 'Núi',
    'Night Markets': 'Chợ đêm',
    'Workshops': 'Workshop',
    'Handmade Goods': 'Đồ thủ công',
    'Scenic Spots': 'Điểm ngắm cảnh',
    'Wellness': 'Chăm sóc sức khỏe',
    'What type of trip are you planning?':
        'Bạn đang lên kế hoạch chuyến đi nào?',
    'Relax, explore, and enjoy\nyour vacation':
        'Thư giãn, khám phá và tận hưởng\nkỳ nghỉ',
    'Meetings, conferences, and\nnetworking': 'Họp, hội nghị và\nkết nối',
    'Museums, temples, heritage': 'Bảo tàng, đền chùa, di sản',
    'Hiking, beaches, parks': 'Leo núi, biển, công viên',
    'Sports, thrills, exploration': 'Thể thao, thử thách, khám phá',
    'Shopping, nightlife, events': 'Mua sắm, đêm, sự kiện',
    'Where do\nyou want\nto go?': 'Bạn muốn\nđi đâu?',
    'When are\nyou free to\ntravel?': 'Khi nào\nbạn rảnh?',
    'Where to?': 'Đi đâu?',
    'Choose your dream destination': 'Chọn điểm đến mơ ước',
    'Back': 'Quay lại',
    'Ok': 'OK',
    'Personal Data': 'Dữ liệu cá nhân',
    'All Images': 'Tất cả ảnh',
    'Images': 'Ảnh',
    'Reviews': 'Đánh giá',
    'What to expect': 'Trải nghiệm nổi bật',
    'More': 'Xem thêm',
    'Less': 'Thu gọn',
    'Best time to visit': 'Thời điểm đẹp nhất',
    'Recommended season': 'Mùa gợi ý',
    'Location': 'Vị trí',
    'Ingredients': 'Nguyên liệu',
    'Flavor': 'Hương vị',
    'The highlights of a visit': 'Điểm nổi bật khi ghé thăm',
    'All Category': 'Tất cả danh mục',
    'Map placeholder': 'Bản đồ',
    'Image placeholder': 'Hình ảnh',
    'Please sign in to update wishlist.':
        'Vui lòng đăng nhập để cập nhật yêu thích.',
    'Please click the reset link in your email first, or try refreshing the page':
        'Vui lòng bấm liên kết trong email trước, hoặc thử tải lại trang',
    'Session verified! You can now set your new password.':
        'Đã xác thực phiên. Bạn có thể đặt mật khẩu mới.',
    'No active session found. Please click the reset link in your email.':
        'Không tìm thấy phiên. Vui lòng bấm liên kết trong email.',
    'Failed to verify session. Please try again.':
        'Không thể xác thực phiên. Vui lòng thử lại.',
    'Password reset email resent! Check your inbox.':
        'Đã gửi lại email đặt mật khẩu. Kiểm tra hộp thư nhé.',
    'Failed to resend email. Please try again.':
        'Không thể gửi lại email. Vui lòng thử lại.',
    'Too many reset emails sent. Please wait 1 hour before trying again.':
        'Bạn đã gửi quá nhiều email. Vui lòng chờ 1 giờ rồi thử lại.',
    'Password reset email sent! Check your inbox.':
        'Đã gửi email đặt lại mật khẩu. Kiểm tra hộp thư nhé.',
    'Failed to send reset email. Please try again.':
        'Không thể gửi email đặt lại. Vui lòng thử lại.',
    'Please click the reset link in your email first':
        'Vui lòng bấm liên kết trong email trước',
    'Password must be at least 6 characters long':
        'Mật khẩu phải có ít nhất 6 ký tự',
    'Password updated successfully': 'Đã cập nhật mật khẩu',
    'Failed to update password. Please try again.':
        'Không thể cập nhật mật khẩu. Vui lòng thử lại.',
    'Discover Vietnamese Culture and\nLocal Specialties':
        'Khám phá văn hóa Việt Nam và\nđặc sản địa phương',
    'ACTIVITIES': 'HOẠT ĐỘNG',
    'CULTURE': 'VĂN HÓA',
    'FOOD': 'ẨM THỰC',
    'LOCAL PRODUCTS': 'ĐẶC SẢN',
    'Hands-on experiences and cultural activities':
        'Trải nghiệm thực tế và hoạt động văn hóa',
    'Traditional customs, heritage, and cultural practices':
        'Phong tục truyền thống, di sản và thực hành văn hóa',
    'Local dishes and culinary specialties from different regions':
        'Món ăn địa phương và đặc sản ẩm thực từ nhiều vùng miền',
    'Traditional goods and handcrafted regional products':
        'Sản phẩm truyền thống và đồ thủ công địa phương',
    'Floating market': 'Chợ nổi',
    'Dropping water lanterns': 'Thả hoa đăng',
    'Water puppetry': 'Múa rối nước',
    'Traditional craft villages': 'Làng nghề truyền thống',
    'Beef noodle soup': 'Phở bò',
    'Pho': 'Phở',
    'Banh mi': 'Bánh mì',
    'Bun bo': 'Bún bò',
    'Conical hats': 'Nón lá',
    'Bat Trang pottery': 'Gốm Bát Tràng',
    'Choose Avatar': 'Chọn ảnh đại diện',
    'Choose photo from device': 'Chọn ảnh từ thiết bị',
    'Remove uploaded avatar': 'Gỡ ảnh đã tải lên',
    'Avatar updated.': 'Đã cập nhật ảnh đại diện.',
    'Upload avatar failed': 'Tải ảnh đại diện thất bại',
    'Uploaded avatar removed.': 'Đã gỡ ảnh đại diện đã tải lên.',
    'Remove avatar failed': 'Gỡ ảnh đại diện thất bại',
    'Could not load reviews right now.': 'Hiện chưa tải được đánh giá.',
    'Write a review': 'Viết đánh giá',
    'Edit your review': 'Sửa đánh giá của bạn',
    'Publish review': 'Đăng đánh giá',
    'Update review': 'Cập nhật đánh giá',
    'Save review': 'Lưu đánh giá',
    'Could not publish your review.': 'Không thể đăng đánh giá của bạn.',
    'Share what stood out for you...': 'Chia sẻ điều khiến bạn ấn tượng...',
    'Traveler': 'Du khách',
    'See all': 'Xem tất cả',
    'Update wishlist failed': 'Cập nhật yêu thích thất bại',
    'Please choose a valid province or city suggestion.':
        'Vui lòng chọn một gợi ý tỉnh hoặc thành phố hợp lệ.',
    'Loyalty Rewards': 'Điểm thưởng thành viên',
    'Content is being updated.': 'Nội dung đang được cập nhật.',
    'Explore by city': 'Khám phá theo thành phố',
    'Feature with issue': 'Tính năng gặp lỗi',
    'Expired': 'Đã hết hạn',
    'Expires today': 'Hết hạn hôm nay',
    'Free account': 'Tài khoản miễn phí',
    'No active subscription': 'Chưa có gói đang hoạt động',
    'No payment history yet.': 'Chưa có lịch sử thanh toán.',
    'Payment history': 'Lịch sử thanh toán',
    'Premium 1 Month': 'Premium 1 tháng',
    'Premium 6 Months': 'Premium 6 tháng',
    'Premium 12 Months': 'Premium 12 tháng',
    'Premium active': 'Premium đang hoạt động',
    'Valid until': 'Có hiệu lực đến',
    'days remaining': 'ngày còn lại',
    'Loyalty updated successfully.': 'Đã cập nhật điểm thưởng.',
    'Daily login is awarded automatically.':
        'Điểm đăng nhập hằng ngày được cộng tự động.',
    'Generating...': 'Đang tạo lịch trình...',
    'Saving…': 'Đang lưu…',
    'Share': 'Chia sẻ',
    'Share to Forum': 'Chia sẻ lên Diễn đàn',
    'Get Directions': 'Chỉ đường',
    'Duration': 'Thời lượng',
    'Price': 'Giá',
    'Open': 'Mở cửa',
    'Phone': 'Điện thoại',
    'Website': 'Trang web',
    'Address': 'Địa chỉ',
    'From': 'Từ',
    'Up to': 'Tối đa',
    'min': 'phút',
    'h': ' giờ',
    'm': ' phút',
    'Create Trip on Google Maps': 'Tạo chuyến đi trên Google Maps',
    'Back to trip planner': 'Quay lại Lịch trình',
    'Destinations': 'Điểm đến',
    'No destinations available yet.': 'Hiện chưa có điểm đến.',
    'Generating your personalised itinerary…':
        'Đang tạo lịch trình dành riêng cho bạn…',
    'No plan ID — please generate again.':
        'Không tìm thấy mã lịch trình — vui lòng tạo lại.',
    'Could not save trip. Please try again.':
        'Không thể lưu chuyến đi. Vui lòng thử lại.',
    'Save the trip first before sharing.':
        'Vui lòng lưu chuyến đi trước khi chia sẻ.',
    'Share this trip plan as a forum post? Other users can save it to their own trips.':
        'Chia sẻ lịch trình này thành bài viết trên diễn đàn? Người dùng khác có thể lưu vào chuyến đi của họ.',
    'Please sign in to share.': 'Vui lòng đăng nhập để chia sẻ.',
    'Could not share. Please try again.':
        'Không thể chia sẻ. Vui lòng thử lại.',
    'Days': 'Ngày',
    'Full': 'Đầy đủ',
    'Schedule': 'Lịch trình',
    'Your Itinerary': 'Lịch trình của bạn',
    'Start Trip': 'Bắt đầu chuyến đi',
    'Nearby': 'Gần đây',
    'Sort by: Nearest': 'Sắp xếp: Gần nhất',
    'No nearby places found.': 'Không tìm thấy địa điểm lân cận.',
    'Route': 'Chỉ đường',
    'Could not load trip. Please try again.':
        'Không thể tải chuyến đi. Vui lòng thử lại.',
    'This trip is no longer available. Please generate it again.':
        'Chuyến đi này không còn khả dụng. Vui lòng tạo lại.',
    'Trip saved!': 'Đã lưu chuyến đi!',
    'Shared to Forum!': 'Đã chia sẻ lên Diễn đàn!',
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
    'Add 500 test points': 'Cộng 500 điểm kiểm thử',
    '+500 points, +500 tier points. Temporary test action.':
        '+500 điểm, +500 điểm hạng. Thao tác kiểm thử tạm thời.',
    'Add': 'Cộng',
    'Unable to add test loyalty points.':
        'Không thể cộng điểm thưởng kiểm thử.',
    'Exchange points to tokens': 'Đổi điểm thành token',
    'Get 1 token': 'Nhận 1 token',
    'Get 5 tokens': 'Nhận 5 token',
    'Redeem vouchers': 'Đổi voucher',
    'Voucher wallet': 'Ví voucher',
    'Transaction history': 'Lịch sử giao dịch',
    'No active loyalty vouchers yet.': 'Chưa có voucher điểm thưởng.',
    'Your loyalty voucher wallet is empty.': 'Ví voucher của bạn đang trống.',
    'No loyalty transactions yet.': 'Chưa có giao dịch điểm thưởng.',
    'Load loyalty failed.': 'Không tải được điểm thưởng.',
    'Loading loyalty rewards': 'Đang tải điểm thưởng',
    'Retry': 'Thử lại',
    'Needs review': 'Cần xét duyệt',
    'Automatic': 'Tự động',
    'pending': 'Đang chờ',
    'completed': 'Đã hoàn thành',
    'active': 'Đang hoạt động',
    'Platinum': 'Hạng Bạch kim',
    'Wishlist': 'Danh sách yêu thích',
    'Loading wishlist': 'Đang tải danh sách yêu thích',
    'Load wishlist failed.': 'Không tải được danh sách yêu thích.',
    'Sign in': 'Đăng nhập',
    'Could not open image': 'Không mở được ảnh',
    'AI Travel Assistant': 'Trợ lý du lịch AI',
    'Hi! Planning a Vietnam trip? Ask me anything.':
        'Xin chào! Bạn sắp khám phá Việt Nam? Cứ hỏi mình nhé.',
    'Where shall we explore in Vietnam?':
        'Mình cùng khám phá nơi nào ở Việt Nam?',
    'Chat history': 'Lịch sử trò chuyện',
    'Could not load this conversation': 'Không thể tải cuộc trò chuyện này',
    'How can I help with your Vietnam trip?':
        'Tôi có thể giúp gì cho chuyến đi Việt Nam của bạn?',
    'Ask for travel ideas, useful local information, or help finding an app feature.':
        'Hãy hỏi về ý tưởng du lịch, thông tin địa phương hoặc cách tìm một tính năng trong ứng dụng.',
    'Premium travel assistant': 'Trợ lý du lịch Premium',
    'Chat with AI for personalized Vietnam travel help and quick access to relevant app features.':
        'Trò chuyện với AI để nhận hỗ trợ du lịch Việt Nam được cá nhân hóa và mở nhanh tính năng phù hợp.',
    'View Premium plans': 'Xem các gói Premium',
    'Renew Premium to continue this conversation.':
        'Gia hạn Premium để tiếp tục cuộc trò chuyện này.',
    'Renew': 'Gia hạn',
    'Ask about your trip in Vietnam...': 'Hỏi về chuyến đi Việt Nam của bạn...',
    'Send': 'Gửi',
    'Listen': 'Nghe',
    'Try again': 'Thử lại',
    'AI chat history': 'Lịch sử trò chuyện AI',
    'Refresh': 'Làm mới',
    'Delete conversation?': 'Xóa cuộc trò chuyện?',
    'This conversation and all its messages will be removed.':
        'Cuộc trò chuyện này và toàn bộ tin nhắn sẽ bị xóa.',
    'Delete': 'Xóa',
    'Could not delete this conversation.': 'Không thể xóa cuộc trò chuyện này.',
    'Could not load chat history': 'Không thể tải lịch sử trò chuyện',
    'Check your connection and try again.': 'Hãy kiểm tra kết nối và thử lại.',
    'No conversations yet': 'Chưa có cuộc trò chuyện',
    'Your AI travel conversations will appear here.':
        'Các cuộc trò chuyện với trợ lý du lịch AI sẽ xuất hiện tại đây.',
    'Open AI Travel Assistant': 'Mở Trợ lý du lịch AI',
    'Premium AI Travel Assistant': 'Trợ lý du lịch AI Premium',
    'Open Trip Planner': 'Mở trình lập lịch trình',
    'Open Translate': 'Mở công cụ dịch',
    'Explore Vietnam': 'Khám phá Việt Nam',
    'View Recommendations': 'Xem gợi ý',
    'Open Forum': 'Mở diễn đàn',
    'Open Wishlist': 'Mở danh sách yêu thích',
    'Open AI Recognition': 'Mở AI nhận diện',
    'Open Loyalty Rewards': 'Mở phần thưởng thành viên',
    'Open Popular Apps': 'Mở ứng dụng phổ biến',
    'Open Notifications': 'Mở thông báo',
    'Open Profile': 'Mở hồ sơ',
  };
}
