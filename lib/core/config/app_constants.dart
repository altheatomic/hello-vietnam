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

  // ── Banner video ────────────────────────────────────────
  static const String bannerVideoUrl =
      'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Homepage/banner.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvSG9tZXBhZ2UvYmFubmVyLm1wNCIsImlhdCI6MTc3Mjg2NDk3MSwiZXhwIjoxODA0NDAwOTcxfQ.7SHBp-h8TzDUFPZwMKcrp6gQFctm6K_i6ZMSaLBvEUw';

  // ── Section backgrounds (network images) ────────────────
  static const String destinationBgUrl =
      'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Homepage/destination_bg.jpeg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvSG9tZXBhZ2UvZGVzdGluYXRpb25fYmcuanBlZyIsImlhdCI6MTc3Mjg2NTEzNCwiZXhwIjoxODA0NDAxMTM0fQ.Vumhobr6PzXLziUzPjdhMSgvH1A9N3AkmAWQdK92d8M';

  static const String dishesBgUrl =
      'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Homepage/dishes_bg.jpg?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvSG9tZXBhZ2UvZGlzaGVzX2JnLmpwZyIsImlhdCI6MTc3Mjg2NTE4OCwiZXhwIjoxODA0NDAxMTg4fQ.X02DrlRZOBw8_dzNtRdOGI2YQdTApkMky-KWxZdINLw';

  // ── Local assets (fallback / other) ─────────────────────
  static const String bannerImage = 'assets/images/banner.png';
}
