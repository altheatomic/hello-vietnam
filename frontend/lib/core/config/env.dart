class Env {
  static const supabaseUrl = "https://ziouozppetvvdrzgojcx.supabase.co";
  static const supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inppb3VvenBwZXR2dmRyemdvamN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDk2NTEsImV4cCI6MjA4ODcyNTY1MX0.MwKtbQwep1nDvFNbRF__u4Xyn7z-GTIQ88iq_K9j4B0";

  static const cloudflareMediaUploadFunction = String.fromEnvironment(
    'CLOUDFLARE_MEDIA_UPLOAD_FUNCTION',
    defaultValue: 'media-upload',
  );
  static const cloudflareMediaPublicBaseUrl = String.fromEnvironment(
    'CLOUDFLARE_MEDIA_PUBLIC_BASE_URL',
    defaultValue: 'https://pub-92f9bcecf7874fc4bcc402bde56011f7.r2.dev',
  );
  static const subscriptionPaymentFunction = String.fromEnvironment(
    'SUBSCRIPTION_PAYMENT_FUNCTION',
    defaultValue: 'subscription-payment',
  );
  static const exploreFunction = String.fromEnvironment(
    'EXPLORE_FUNCTION',
    defaultValue: 'explore',
  );
}
