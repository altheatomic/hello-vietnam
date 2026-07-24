import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/ai_chat/application/ai_chat_action_catalog.dart';

void main() {
  const Map<String, String> expectedRoutes = <String, String>{
    'trip_planner': AppRoutes.tripPlanner,
    'translate': AppRoutes.translate,
    'explore': AppRoutes.explore,
    'recommend': AppRoutes.recommend,
    'forum': AppRoutes.messages,
    'wishlist': AppRoutes.wishlist,
    'ai_recognition': AppRoutes.aiSearch,
    'loyalty': AppRoutes.loyalty,
    'popular_apps': AppRoutes.popularApps,
    'notifications': AppRoutes.notification,
    'profile': AppRoutes.profile,
    'send_report': AppRoutes.feedback,
    'upgrade_account': AppRoutes.upgradeAccount,
  };

  test('every supported action maps to one fixed application route', () {
    for (final MapEntry<String, String> entry in expectedRoutes.entries) {
      expect(
        AiChatActionCatalog.destinationFor(entry.key)?.route,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('unknown, URL-shaped, and route-shaped actions are rejected', () {
    for (final String value in <String>[
      '',
      'unknown',
      'https://example.com',
      '/profile',
      'profile?admin=true',
    ]) {
      expect(AiChatActionCatalog.destinationFor(value), isNull, reason: value);
    }
  });

  test('catalog contains exactly the server allowlist', () {
    expect(AiChatActionCatalog.destinations.keys, expectedRoutes.keys);
  });
}
