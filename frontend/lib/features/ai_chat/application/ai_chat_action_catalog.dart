import 'package:flutter/material.dart';

import '../../../app/router.dart';

class AiChatActionDestination {
  const AiChatActionDestination({
    required this.key,
    required this.route,
    required this.label,
    required this.icon,
  });

  final String key;
  final String route;
  final String label;
  final IconData icon;
}

abstract final class AiChatActionCatalog {
  static const Map<String, AiChatActionDestination> destinations =
      <String, AiChatActionDestination>{
        'trip_planner': AiChatActionDestination(
          key: 'trip_planner',
          route: AppRoutes.tripPlanner,
          label: 'Open Trip Planner',
          icon: Icons.calendar_month_outlined,
        ),
        'translate': AiChatActionDestination(
          key: 'translate',
          route: AppRoutes.translate,
          label: 'Open Translate',
          icon: Icons.translate_outlined,
        ),
        'explore': AiChatActionDestination(
          key: 'explore',
          route: AppRoutes.explore,
          label: 'Explore Vietnam',
          icon: Icons.explore_outlined,
        ),
        'recommend': AiChatActionDestination(
          key: 'recommend',
          route: AppRoutes.recommend,
          label: 'View Recommendations',
          icon: Icons.recommend_outlined,
        ),
        'forum': AiChatActionDestination(
          key: 'forum',
          route: AppRoutes.messages,
          label: 'Open Forum',
          icon: Icons.forum_outlined,
        ),
        'wishlist': AiChatActionDestination(
          key: 'wishlist',
          route: AppRoutes.wishlist,
          label: 'Open Wishlist',
          icon: Icons.favorite_border,
        ),
        'ai_recognition': AiChatActionDestination(
          key: 'ai_recognition',
          route: AppRoutes.aiSearch,
          label: 'Open AI Recognition',
          icon: Icons.auto_awesome_outlined,
        ),
        'loyalty': AiChatActionDestination(
          key: 'loyalty',
          route: AppRoutes.loyalty,
          label: 'Open Loyalty Rewards',
          icon: Icons.workspace_premium_outlined,
        ),
        'popular_apps': AiChatActionDestination(
          key: 'popular_apps',
          route: AppRoutes.popularApps,
          label: 'Open Popular Apps',
          icon: Icons.apps_outlined,
        ),
        'notifications': AiChatActionDestination(
          key: 'notifications',
          route: AppRoutes.notification,
          label: 'Open Notifications',
          icon: Icons.notifications_outlined,
        ),
        'profile': AiChatActionDestination(
          key: 'profile',
          route: AppRoutes.profile,
          label: 'Open Profile',
          icon: Icons.person_outline,
        ),
        'send_report': AiChatActionDestination(
          key: 'send_report',
          route: AppRoutes.feedback,
          label: 'Send Report',
          icon: Icons.report_outlined,
        ),
        'upgrade_account': AiChatActionDestination(
          key: 'upgrade_account',
          route: AppRoutes.upgradeAccount,
          label: 'Upgrade Account',
          icon: Icons.workspace_premium_outlined,
        ),
      };

  static AiChatActionDestination? destinationFor(String? actionKey) {
    return actionKey == null ? null : destinations[actionKey];
  }
}
