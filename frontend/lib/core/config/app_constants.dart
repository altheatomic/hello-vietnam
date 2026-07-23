/// Central place for layout constants, URLs, and asset paths.
class AppConstants {
  AppConstants._();

  // ── Layout ──────────────────────────────────────────────
  static const double pagePadding = 16.0;
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double glassBlur = 12.0;
  static const double glassOpacity = 0.15;

  // ── Animation ───────────────────────────────────────────
  static const Duration defaultAnimation = Duration(milliseconds: 300);

  // ── Homepage assets ─────────────────────────────────────
  static const String bannerStaticAsset =
      'assets/images/homepage/banner_static.jpg';
  static const String destinationBgAsset =
      'assets/images/homepage/bestdestination_bg.jpeg';
  static const String dishesBgAsset =
      'assets/images/homepage/bestdishes_bg.jpeg';
  static const String exploreHeaderBgAsset =
      'assets/images/explore/explore_bg.jpeg';
  static const String recommendWhereCardAsset =
      'assets/images/recommend/where.png';
  static const String recommendWhenCardAsset =
      'assets/images/recommend/when.png';

  // ── Local assets (fallback / other) ─────────────────────
  static const String bannerImage = 'assets/images/banner.png';
}
