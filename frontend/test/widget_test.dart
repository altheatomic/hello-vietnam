import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/app.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  });

  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(App(router: buildRouter()));
    await tester.pumpAndSettle();
    expect(find.byType(App), findsOneWidget);
  });
}
