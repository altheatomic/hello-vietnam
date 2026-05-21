class Env {
  static const supabaseUrl = "https://ziouozppetvvdrzgojcx.supabase.co";
  static const supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inppb3VvenBwZXR2dmRyemdvamN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDk2NTEsImV4cCI6MjA4ODcyNTY1MX0.MwKtbQwep1nDvFNbRF__u4Xyn7z-GTIQ88iq_K9j4B0";
  static const avatarStorageProjectUrl = String.fromEnvironment(
    'AVATAR_STORAGE_PROJECT_URL',
    defaultValue: 'https://rpvwneveukpsnxlvdsev.supabase.co',
  );
  static const avatarStorageAnonKey = String.fromEnvironment(
    'AVATAR_STORAGE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwdnduZXZldWtwc254bHZkc2V2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyMzI0NDcsImV4cCI6MjA5MTgwODQ0N30.HQs0qKv2HjDWWRcauefMJN6slZBrrLbFVRvEoorXHXQ',
  );
  static const avatarStorageBucket = String.fromEnvironment(
    'AVATAR_STORAGE_BUCKET',
    defaultValue: 'Image',
  );
  static const forumMediaBucket = String.fromEnvironment(
    'FORUM_MEDIA_BUCKET',
    defaultValue: 'forum-media',
  );

  static bool get hasExternalAvatarStorage =>
      avatarStorageAnonKey.trim().isNotEmpty;
}
