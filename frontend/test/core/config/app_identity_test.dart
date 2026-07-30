import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/app_identity.dart';

void main() {
  test('Android production identity stays synchronized', () {
    expect(AppIdentity.androidApplicationId, 'com.hellovietnam.app');
    expect(AppIdentity.androidUrlScheme, AppIdentity.androidApplicationId);
    expect(
      AppIdentity.loginCallbackUrl,
      'com.hellovietnam.app://login-callback',
    );
    expect(
      AppIdentity.resetPasswordCallbackUrl,
      'com.hellovietnam.app://reset-password',
    );
  });
}
