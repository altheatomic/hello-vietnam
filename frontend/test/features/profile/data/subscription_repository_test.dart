import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';

void main() {
  test(
    'loadPlan reads subscription plan through shared table client',
    () async {
      final _FakeTableClient tableClient = _FakeTableClient(
        maybeSingleRows: <Map<String, dynamic>?>[
          <String, dynamic>{
            'id_subscription_plan': 'plan-6m',
            'code': '6m',
            'name': 'Premium 6 Months',
            'duration_days': 180,
            'price_minor': 1999,
          },
        ],
      );
      final SubscriptionRepository repository = SubscriptionRepository(
        tableClient: tableClient,
      );

      final SubscriptionPlanInfo plan = await repository.loadPlan('6m');

      expect(tableClient.maybeSingleLabels, <String>['subscription plan']);
      expect(plan.id, 'plan-6m');
      expect(plan.code, '6m');
      expect(plan.durationDays, 180);
      expect(plan.priceMinor, 1999);
    },
  );

  test(
    'createStripeCheckout delegates payload to shared function client',
    () async {
      Object? capturedBody;

      final SubscriptionRepository repository = SubscriptionRepository(
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                expect(functionName, Env.subscriptionPaymentFunction);
                capturedBody = body;
                return <String, dynamic>{
                  'status': 'requires_checkout',
                  'checkoutUrl': 'https://checkout.stripe.test/session',
                  'sessionId': 'cs_test_123',
                };
              },
        ),
      );

      final SubscriptionCheckoutResult result = await repository
          .createStripeCheckout(
            planCode: '6m',
            voucherCode: 'LOYALTY10',
            successUrl: 'com.hellovietnam.app://upgrade-payment?plan=6m',
            cancelUrl: 'com.hellovietnam.app://upgrade-payment?plan=6m',
          );

      expect(capturedBody, <String, Object?>{
        'action': 'create_checkout',
        'planCode': '6m',
        'voucherCode': 'LOYALTY10',
        'successUrl': 'com.hellovietnam.app://upgrade-payment?plan=6m',
        'cancelUrl': 'com.hellovietnam.app://upgrade-payment?plan=6m',
      });
      expect(result.requiresCheckout, isTrue);
      expect(result.checkoutUrl, 'https://checkout.stripe.test/session');
      expect(result.sessionId, 'cs_test_123');
    },
  );

  test(
    'confirmStripeCheckout parses purchase payload from function client',
    () async {
      Object? capturedBody;

      final SubscriptionRepository repository = SubscriptionRepository(
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                expect(functionName, Env.subscriptionPaymentFunction);
                capturedBody = body;
                return <String, dynamic>{
                  'purchase': <String, dynamic>{
                    'id_payment': 'payment-1',
                    'id_subscription': 'subscription-1',
                    'original_amount_minor': 1999,
                    'discount_minor': 200,
                    'final_amount_minor': 1799,
                    'voucher_code': 'LOYALTY10',
                    'subscription_end_date': '2026-12-31T00:00:00Z',
                  },
                };
              },
        ),
      );

      final SubscriptionPurchaseResult result = await repository
          .confirmStripeCheckout(sessionId: 'cs_test_123');

      expect(capturedBody, <String, Object?>{
        'action': 'confirm_checkout',
        'sessionId': 'cs_test_123',
      });
      expect(result.paymentId, 'payment-1');
      expect(result.subscriptionId, 'subscription-1');
      expect(result.finalAmountMinor, 1799);
      expect(result.voucherCode, 'LOYALTY10');
      expect(
        result.subscriptionEndDate,
        DateTime.parse('2026-12-31T00:00:00Z'),
      );
    },
  );
}

class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({List<Map<String, dynamic>?>? maybeSingleRows})
    : _maybeSingleRows = List<Map<String, dynamic>?>.of(
        maybeSingleRows ?? const <Map<String, dynamic>?>[],
      );

  final List<Map<String, dynamic>?> _maybeSingleRows;
  final List<String> maybeSingleLabels = <String>[];

  @override
  Future<Map<String, dynamic>?> maybeSingle(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    maybeSingleLabels.add(label);
    if (_maybeSingleRows.isEmpty) return null;
    return _maybeSingleRows.removeAt(0);
  }
}
