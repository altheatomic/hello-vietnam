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

    test('maps a verified HTTPS shared-trip URL to the public app route', () {
      final Uri uri = Uri.parse(
        'https://share.hellovietnam.test/trip/abc_123-XYZ',
      );

      expect(
        appRouteLocationFromDeepLink(
          uri,
          shareHosts: const <String>{'share.hellovietnam.test'},
        ),
        '/shared-trip?token=abc_123-XYZ',
      );
    });

    test('rejects shared-trip URLs from an untrusted host', () {
      final Uri uri = Uri.parse('https://evil.test/trip/abc_123-XYZ');

      expect(
        appRouteLocationFromDeepLink(
          uri,
          shareHosts: const <String>{'share.hellovietnam.test'},
        ),
        isNull,
      );
    });

    test('maps the web viewer open-app fallback to the shared-trip route', () {
      final Uri uri = Uri.parse(
        'com.hellovietnam.app://shared-trip?token=abc_123-XYZ',
      );

      expect(
        appRouteLocationFromDeepLink(uri),
        '/shared-trip?token=abc_123-XYZ',
      );
    });
  });
}
