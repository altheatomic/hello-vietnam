import 'package:flutter_test/flutter_test.dart';
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
}
