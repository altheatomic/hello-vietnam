abstract final class AppIdentity {
  static const String androidApplicationId = 'com.hellovietnam.app';
  static const String androidUrlScheme = androidApplicationId;
  static const String loginCallbackUrl = '$androidUrlScheme://login-callback';
  static const String resetPasswordCallbackUrl =
      '$androidUrlScheme://reset-password';
}
