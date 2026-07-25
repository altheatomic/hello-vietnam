import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_launcher_position_store.dart';
import 'package:hellovietnam/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget buildLauncher({
    required bool isPremium,
    VoidCallback? onOpenChat,
    VoidCallback? onUpgrade,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AiChatHomeLauncher(
          premiumLoader: () async => isPremium,
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
    await tester.pumpWidget(
      buildLauncher(
        isPremium: true,
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

  testWidgets('shows a lock and opens Upgrade for a free user', (
    WidgetTester tester,
  ) async {
    int openedChat = 0;
    int openedUpgrade = 0;
    await tester.pumpWidget(
      buildLauncher(
        isPremium: false,
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

  testWidgets('persists the launcher position after dragging', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildLauncher(isPremium: true));
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
