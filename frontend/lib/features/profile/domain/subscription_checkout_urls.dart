import '../../../core/config/app_identity.dart';

String subscriptionCheckoutReturnUrl(
  String planCode, {
  required bool success,
  required bool isWeb,
  required String webOrigin,
}) {
  final String encodedPlan = Uri.encodeComponent(planCode);
  if (!isWeb) {
    if (success) {
      return 'intent://upgrade-payment?plan=$encodedPlan'
          '&stripe_session_id={CHECKOUT_SESSION_ID}'
          '#Intent;scheme=${AppIdentity.androidUrlScheme};'
          'package=${AppIdentity.androidApplicationId};end';
    }
    return 'intent://upgrade-payment?plan=$encodedPlan&stripe_cancelled=1'
        '#Intent;scheme=${AppIdentity.androidUrlScheme};'
        'package=${AppIdentity.androidApplicationId};end';
  }

  if (success) {
    return '$webOrigin/#/upgrade-payment?plan=$encodedPlan'
        '&stripe_session_id={CHECKOUT_SESSION_ID}';
  }
  return '$webOrigin/#/upgrade-payment?plan=$encodedPlan&stripe_cancelled=1';
}
