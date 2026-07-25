import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hellovietnam/app/app.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  });

  setUp(() async {
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(App(router: buildRouter()));
    await tester.pumpAndSettle();
    expect(find.byType(App), findsOneWidget);
  });

  testWidgets('bottom navigation uses Vietnamese labels', (
    WidgetTester tester,
  ) async {
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(App(router: router));
    router.go(AppRoutes.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    for (final String label in <String>[
      'Trang chủ',
      'Lịch trình',
      'Đã lưu',
      'Diễn đàn',
      'Hồ sơ',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1), reason: label);
    }
    for (final String label in <String>[
      'Home',
      'Planner',
      'Saved',
      'Forum',
      'Profile',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('bottom navigation morphs like liquid glass between tabs', (
    WidgetTester tester,
  ) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(App(router: router));
    router.go(AppRoutes.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final Transform restingMorph = tester.widget<Transform>(
      find.byKey(const Key('liquid-nav-morph')),
    );
    final Container navSurface = tester.widget<Container>(
      find.byKey(const Key('liquid-nav-surface')),
    );
    final LinearGradient surfaceGradient =
        (navSurface.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(restingMorph.transform.storage[0], closeTo(1, 0.001));
    expect(restingMorph.transform.storage[5], closeTo(1, 0.001));
    expect(surfaceGradient.colors.first.a, lessThan(0.55));

    await tester.tap(find.byKey(const Key('bottom-nav-forum')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    final Transform activeMorph = tester.widget<Transform>(
      find.byKey(const Key('liquid-nav-morph')),
    );
    expect(activeMorph.transform.storage[0], greaterThan(1.05));
    expect(activeMorph.transform.storage[5], lessThan(0.99));

    await tester.pump(const Duration(milliseconds: 600));
    final Transform settledMorph = tester.widget<Transform>(
      find.byKey(const Key('liquid-nav-morph')),
    );
    expect(settledMorph.transform.storage[0], closeTo(1, 0.001));
    expect(settledMorph.transform.storage[5], closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });
}
