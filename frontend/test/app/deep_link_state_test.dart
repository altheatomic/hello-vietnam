import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/deep_link_state.dart';

void main() {
  group('appRouteLocationFromDeepLink', () {
    test('maps the production Android payment callback to the app route', () {
      final Uri uri = Uri.parse(
        'com.hellovietnam.app://upgrade-payment'
        '?plan=6m&stripe_session_id=cs_test_123',
      );

      expect(
        appRouteLocationFromDeepLink(uri),
        '/upgrade-payment?plan=6m&stripe_session_id=cs_test_123',
      );
    });

    test('rejects the retired example-package callback', () {
      final Uri uri = Uri.parse(
        'com.example.hellovietnam://upgrade-payment?plan=6m',
      );

      expect(appRouteLocationFromDeepLink(uri), isNull);
    });
  });
}
