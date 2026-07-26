import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_launcher_position_store.dart';
import 'package:hellovietnam/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  CurrentSubscriptionInfo activeSubscription() {
    return CurrentSubscriptionInfo(
      planCode: '6m',
      planName: 'Premium 6 Months',
      durationDays: 180,
      endDate: DateTime.utc(2026, 12, 14),
    );
  }

  Widget buildLauncher({
    required PremiumEntitlementController controller,
    VoidCallback? onOpenChat,
    VoidCallback? onUpgrade,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AiChatHomeLauncher(
          entitlementController: controller,
          onOpenChat: onOpenChat,
          onUpgrade: onUpgrade,
        ),
      ),
    );
  }

  testWidgets('opens chat for an active Premium user', (
    WidgetTester tester,
  ) async {
    int openedChat = 0;
    int openedUpgrade = 0;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => activeSubscription(),
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      buildLauncher(
        controller: controller,
        onOpenChat: () => openedChat++,
        onUpgrade: () => openedUpgrade++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-chat-home-lock')), findsNothing);
    await tester.tap(find.byKey(const Key('ai-chat-home-launcher')));

    expect(openedChat, 1);
    expect(openedUpgrade, 0);
  });

  testWidgets('shows a lock and opens Upgrade only when confirmed inactive', (
    WidgetTester tester,
  ) async {
    int openedChat = 0;
    int openedUpgrade = 0;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => null,
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      buildLauncher(
        controller: controller,
        onOpenChat: () => openedChat++,
        onUpgrade: () => openedUpgrade++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-chat-home-lock')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-chat-home-launcher')));

    expect(openedChat, 0);
    expect(openedUpgrade, 1);
  });

  testWidgets('shows retry rather than lock for verification error', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async =>
              throw const SupabaseTableException('down'),
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(buildLauncher(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-chat-home-retry')), findsOneWidget);
    expect(find.byKey(const Key('ai-chat-home-lock')), findsNothing);
  });

  testWidgets('mounted launcher unlocks after a later successful refresh', (
    WidgetTester tester,
  ) async {
    var fail = true;
    var openedChat = 0;
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
    await controller.refresh();

    await tester.pumpWidget(
      buildLauncher(controller: controller, onOpenChat: () => openedChat++),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-chat-home-retry')), findsOneWidget);

    fail = false;
    await controller.refresh(force: true);
    await tester.pump();
    expect(find.byKey(const Key('ai-chat-home-lock')), findsNothing);
    expect(find.byKey(const Key('ai-chat-home-retry')), findsNothing);

    await tester.tap(find.byKey(const Key('ai-chat-home-launcher')));
    expect(openedChat, 1);
  });

  testWidgets('persists the launcher position after dragging', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => activeSubscription(),
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(buildLauncher(controller: controller));
    await tester.pumpAndSettle();
    final AiChatLauncherPositionStore store = AiChatLauncherPositionStore();
    final AiChatLauncherPosition before = await store.load();

    await tester.drag(
      find.byKey(const Key('ai-chat-home-launcher')),
      const Offset(-120, -80),
    );
    await tester.pumpAndSettle();
    final AiChatLauncherPosition after = await store.load();

    expect(after.x, lessThan(before.x));
    expect(after.y, lessThan(before.y));
  });
}
