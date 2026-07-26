import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CurrentSubscriptionInfo activeSubscription([DateTime? endDate]) {
    return CurrentSubscriptionInfo(
      planCode: '6m',
      planName: 'Premium 6 Months',
      durationDays: 180,
      endDate: endDate ?? DateTime.utc(2026, 12, 14),
    );
  }

  test('successful active row produces active', () async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => activeSubscription(),
          currentUserId: () => 'user-1',
          now: () => DateTime.utc(2026, 7, 27),
        );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.state.status, PremiumEntitlementStatus.active);
    expect(controller.canUsePremium, isTrue);
  });

  test('successful empty result produces confirmed inactive', () async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => null,
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.state.status, PremiumEntitlementStatus.inactive);
    expect(controller.state.isConfirmedInactive, isTrue);
  });

  test('request failure produces error instead of inactive', () async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async =>
              throw const SupabaseTableException('failed'),
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.state.status, PremiumEntitlementStatus.error);
    expect(controller.state.isConfirmedInactive, isFalse);
  });

  test('transient failure retains an unexpired active entitlement', () async {
    var fail = false;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async {
            if (fail) {
              throw const SupabaseTableException('temporary');
            }
            return activeSubscription(DateTime.utc(2026, 12, 14));
          },
          currentUserId: () => 'user-1',
          now: () => DateTime.utc(2026, 7, 27),
        );
    addTearDown(controller.dispose);

    await controller.refresh();
    fail = true;
    await controller.refresh(force: true);

    expect(controller.state.status, PremiumEntitlementStatus.active);
    expect(controller.state.error, isNotNull);
    expect(controller.canUsePremium, isTrue);
  });

  test('failure after local expiry does not retain active access', () async {
    var now = DateTime.utc(2026, 7, 27);
    var fail = false;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async {
            if (fail) {
              throw const SupabaseTableException('temporary');
            }
            return activeSubscription(DateTime.utc(2026, 7, 28));
          },
          currentUserId: () => 'user-1',
          now: () => now,
        );
    addTearDown(controller.dispose);

    await controller.refresh();
    now = DateTime.utc(2026, 7, 29);
    fail = true;
    await controller.refresh(force: true);

    expect(controller.state.status, PremiumEntitlementStatus.error);
    expect(controller.canUsePremium, isFalse);
  });

  test('deduplicates non-forced refreshes for the same user', () async {
    var calls = 0;
    final Completer<CurrentSubscriptionInfo?> pending =
        Completer<CurrentSubscriptionInfo?>();
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () {
            calls++;
            return pending.future;
          },
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    final Future<void> first = controller.refresh();
    final Future<void> second = controller.refresh();
    expect(calls, 1);

    pending.complete(activeSubscription());
    await Future.wait(<Future<void>>[first, second]);
  });

  test('forced refresh supersedes an older response', () async {
    final List<Completer<CurrentSubscriptionInfo?>> requests =
        <Completer<CurrentSubscriptionInfo?>>[];
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () {
            final Completer<CurrentSubscriptionInfo?> request =
                Completer<CurrentSubscriptionInfo?>();
            requests.add(request);
            return request.future;
          },
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    final Future<void> older = controller.refresh();
    final Future<void> newer = controller.refresh(force: true);
    requests[1].complete(null);
    await newer;
    requests[0].complete(activeSubscription());
    await older;

    expect(controller.state.status, PremiumEntitlementStatus.inactive);
  });

  test('response from a previous user is ignored', () async {
    var userId = 'user-1';
    final List<Completer<CurrentSubscriptionInfo?>> requests =
        <Completer<CurrentSubscriptionInfo?>>[];
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () {
            final Completer<CurrentSubscriptionInfo?> request =
                Completer<CurrentSubscriptionInfo?>();
            requests.add(request);
            return request.future;
          },
          currentUserId: () => userId,
        );
    addTearDown(controller.dispose);

    final Future<void> first = controller.refresh();
    userId = 'user-2';
    final Future<void> second = controller.refresh(force: true);
    requests[1].complete(null);
    await second;
    requests[0].complete(activeSubscription());
    await first;

    expect(controller.state.userId, 'user-2');
    expect(controller.state.status, PremiumEntitlementStatus.inactive);
  });

  test('auth user change refreshes and sign-out clears state', () async {
    String? currentUserId = 'user-1';
    final StreamController<String?> authChanges =
        StreamController<String?>.broadcast();
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => activeSubscription(),
          currentUserId: () => currentUserId,
          authUserIds: authChanges.stream,
        );
    addTearDown(controller.dispose);
    addTearDown(authChanges.close);

    controller.initialize();
    await controller.refresh();
    expect(controller.canUsePremium, isTrue);

    currentUserId = null;
    authChanges.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, PremiumEntitlementStatus.inactive);
    expect(controller.state.userId, isNull);
    expect(controller.state.subscription, isNull);
  });

  test('app resume forces a fresh entitlement request', () async {
    var calls = 0;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async {
            calls++;
            return activeSubscription();
          },
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);

    controller.initialize();
    await controller.refresh();
    final int callsAfterInitialize = calls;

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(calls, callsAfterInitialize + 1);
  });
}
