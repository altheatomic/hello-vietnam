import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  });

  test('router registers AI chat and AI chat history routes', () {
    final GoRouter router = buildRouter();
    addTearDown(router.dispose);

    final Set<String> paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((GoRoute route) => route.path)
        .toSet();

    expect(paths, contains(AppRoutes.aiChat));
    expect(paths, contains(AppRoutes.aiChatHistory));
  });
}
