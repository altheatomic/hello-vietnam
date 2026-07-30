import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';
import 'package:hellovietnam/features/profile/presentation/upgrade_account_page.dart';
import 'package:hellovietnam/features/profile/presentation/upgrade_payment_page.dart';

void main() {
  CurrentSubscriptionInfo activeSubscription() {
    return CurrentSubscriptionInfo(
      planCode: '6m',
      planName: 'Premium 6 Months',
      durationDays: 180,
      endDate: DateTime.utc(2026, 12, 14),
    );
  }

  testWidgets('Upgrade displays the controller active subscription', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => activeSubscription(),
          currentUserId: () => 'user-1',
          now: () => DateTime.utc(2026, 7, 27),
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeAccountPage(
          entitlementController: controller,
          repository: _FakeUpgradeRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium active'), findsOneWidget);
    expect(find.textContaining('14/12/2026'), findsWidgets);
  });

  testWidgets('Upgrade retries verification and updates without remounting', (
    WidgetTester tester,
  ) async {
    var fail = true;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async {
            if (fail) {
              throw const SupabaseTableException('temporary');
            }
            return activeSubscription();
          },
          currentUserId: () => 'user-1',
          now: () => DateTime.utc(2026, 7, 27),
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeAccountPage(
          entitlementController: controller,
          repository: _FakeUpgradeRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premium-entitlement-retry')), findsOneWidget);
    expect(find.text('No active subscription'), findsNothing);

    fail = false;
    await tester.tap(find.byKey(const Key('premium-entitlement-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Premium active'), findsOneWidget);
  });

  testWidgets('confirmed inactive shows a purchasable Continue button', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => null,
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeAccountPage(
          entitlementController: controller,
          repository: _FakeUpgradeRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active subscription'), findsOneWidget);
    expect(find.byKey(const Key('upgrade-continue')), findsOneWidget);
  });

  testWidgets('payment result survives entitlement verification failure', (
    WidgetTester tester,
  ) async {
    var fail = true;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async {
            if (fail) {
              throw const SupabaseTableException('temporary');
            }
            return activeSubscription();
          },
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradePaymentPage(
          planId: '6m',
          checkoutSessionId: 'cs_test_123',
          repository: _FakePaymentRepository(),
          entitlementController: controller,
          awardPurchase: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Payment completed'), findsOneWidget);
    expect(find.textContaining('could not verify Premium'), findsOneWidget);
    expect(find.byKey(const Key('payment-premium-retry')), findsOneWidget);

    fail = false;
    await tester.tap(find.byKey(const Key('payment-premium-retry')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Premium Benefits Activated'), findsOneWidget);
    expect(find.textContaining('could not verify Premium'), findsNothing);
  });

  testWidgets('verified payment shows activated benefits immediately', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => activeSubscription(),
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradePaymentPage(
          planId: '6m',
          checkoutSessionId: 'cs_test_123',
          repository: _FakePaymentRepository(),
          entitlementController: controller,
          awardPurchase: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Premium Benefits Activated'), findsOneWidget);
    expect(find.byKey(const Key('payment-premium-retry')), findsNothing);
  });
}

class _FakeUpgradeRepository extends SubscriptionRepository {
  @override
  Future<List<SubscriptionPaymentHistoryItem>> loadPaymentHistory() async {
    return const <SubscriptionPaymentHistoryItem>[];
  }
}

class _FakePaymentRepository extends SubscriptionRepository {
  @override
  Future<SubscriptionPlanInfo> loadPlan(String code) async {
    return fallbackPlan(code);
  }

  @override
  Future<SubscriptionPurchaseResult> confirmStripeCheckout({
    required String sessionId,
  }) async {
    return SubscriptionPurchaseResult(
      paymentId: 'payment-1',
      subscriptionId: 'subscription-1',
      originalAmountMinor: 1999,
      discountMinor: 0,
      finalAmountMinor: 1999,
      voucherCode: null,
      subscriptionEndDate: DateTime.utc(2026, 12, 14),
    );
  }
}
