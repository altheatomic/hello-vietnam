import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/profile/domain/subscription_checkout_urls.dart';

void main() {
  group('subscriptionCheckoutReturnUrl', () {
    test('builds the Android success intent with the production package', () {
      expect(
        subscriptionCheckoutReturnUrl(
          '6m',
          success: true,
          isWeb: false,
          webOrigin: '',
        ),
        'intent://upgrade-payment?plan=6m'
        '&stripe_session_id={CHECKOUT_SESSION_ID}'
        '#Intent;scheme=com.hellovietnam.app;'
        'package=com.hellovietnam.app;end',
      );
    });

    test(
      'builds the Android cancellation intent with the production package',
      () {
        expect(
          subscriptionCheckoutReturnUrl(
            '12m',
            success: false,
            isWeb: false,
            webOrigin: '',
          ),
          'intent://upgrade-payment?plan=12m&stripe_cancelled=1'
          '#Intent;scheme=com.hellovietnam.app;'
          'package=com.hellovietnam.app;end',
        );
      },
    );

    test('keeps the web success callback unchanged', () {
      expect(
        subscriptionCheckoutReturnUrl(
          '6m',
          success: true,
          isWeb: true,
          webOrigin: 'https://hello-vietnam.test',
        ),
        'https://hello-vietnam.test/#/upgrade-payment'
        '?plan=6m&stripe_session_id={CHECKOUT_SESSION_ID}',
      );
    });
  });
}
