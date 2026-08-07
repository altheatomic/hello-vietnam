import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';
import 'package:hellovietnam/features/translate/presentation/translate_page.dart';

void main() {
  testWidgets('typing does not start translation until the user confirms', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TranslatePage()));

    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.pump();

    expect(find.text('Translating...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('uses dark text for the translation input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TranslatePage()));

    final TextField input = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(input.style?.color, const Color(0xFF172033));
    expect(input.cursorColor, const Color(0xFF172033));
  });

  testWidgets('uses the dark scaffold and semantic surfaces', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const TranslatePage()),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, darkTheme.scaffoldBackgroundColor);
    expect(
      tester.widgetList<Container>(find.byType(Container)).where((
        Container item,
      ) {
        final Decoration? decoration = item.decoration;
        return decoration is BoxDecoration &&
            decoration.color == darkTheme.colorScheme.surface;
      }),
      isNotEmpty,
    );
  });

  testWidgets('active entitlement switches to Premium mode', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => _activeSubscription(),
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(_translateTestApp(controller));
    await _selectPremiumMode(tester);
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Upgrade destination'), findsNothing);
  });

  testWidgets('confirmed inactive opens Upgrade', (WidgetTester tester) async {
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async => null,
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(_translateTestApp(controller));
    await _selectPremiumMode(tester);
    await tester.pumpAndSettle();

    expect(find.text('Upgrade destination'), findsOneWidget);
  });

  testWidgets('verification retry unlocks Premium without opening Upgrade', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var shouldFail = true;
    final PremiumEntitlementController controller =
        PremiumEntitlementController(
          loadSubscription: () async {
            if (shouldFail) {
              throw const SupabaseTableException('down');
            }
            return _activeSubscription();
          },
          currentUserId: () => 'user-1',
        );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(_translateTestApp(controller));
    await _selectPremiumMode(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('translate-premium-retry')), findsOneWidget);
    expect(find.text('Upgrade destination'), findsNothing);

    shouldFail = false;
    await tester.tap(find.byKey(const Key('translate-premium-retry')));
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Upgrade destination'), findsNothing);
  });
}

CurrentSubscriptionInfo _activeSubscription() {
  return CurrentSubscriptionInfo(
    planCode: '6m',
    planName: 'Premium 6 Months',
    durationDays: 180,
    endDate: DateTime.utc(2026, 12, 14),
  );
}

Widget _translateTestApp(PremiumEntitlementController controller) {
  final GoRouter router = GoRouter(
    initialLocation: '/translate',
    routes: <RouteBase>[
      GoRoute(
        path: '/translate',
        builder: (_, _) => TranslatePage(entitlementController: controller),
      ),
      GoRoute(
        path: '/profile/upgrade',
        builder: (_, _) => const Scaffold(body: Text('Upgrade destination')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _selectPremiumMode(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Translation mode'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('AI Premium'));
  await tester.pump();
}
