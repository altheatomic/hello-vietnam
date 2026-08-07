import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_shell.dart';
import '../features/admin/domain/admin_content.dart';
import '../features/admin/presentation/pages/admin_canned_replies_page.dart';
import '../features/admin/presentation/pages/admin_content_page.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/admin_food_page.dart';
import '../features/admin/presentation/pages/admin_popular_app_page.dart';
import '../features/admin/presentation/pages/admin_cf_retrain_page.dart';
import '../features/admin/presentation/pages/admin_data_freshness_page.dart';
import '../features/admin/presentation/pages/admin_report_page.dart';
import '../features/admin/presentation/pages/admin_user_page.dart';

class AdminWebRoutes {
  static const dashboard = '/admin/dashboard';
  static const users = '/admin/users';
  static const cannedReplies = '/admin/canned-replies';
  static const reports = '/admin/reports';
  static const food = '/admin/food';
  static const provinces = '/admin/provinces';
  static const places = '/admin/places';
  static const activities = '/admin/activities';
  static const cultures = '/admin/cultures';
  static const localProducts = '/admin/local-products';
  static const popularApps = '/admin/popular-apps';
  static const cfRetrain = '/admin/cf-retrain';
  static const dataFreshness = '/admin/data-freshness';
}

final adminRootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildAdminWebRouter() {
  return GoRouter(
    navigatorKey: adminRootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: AdminWebRoutes.dashboard,
    redirect: (context, state) {
      if (state.uri.path == '/' || state.uri.path.isEmpty) {
        return AdminWebRoutes.dashboard;
      }
      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(currentPath: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AdminWebRoutes.dashboard,
            builder: (c, s) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: AdminWebRoutes.users,
            builder: (c, s) => const AdminUserPage(),
          ),
          GoRoute(
            path: AdminWebRoutes.cannedReplies,
            builder: (c, s) => const AdminCannedRepliesPage(),
          ),
          GoRoute(
            path: AdminWebRoutes.reports,
            builder: (c, s) => const AdminReportPage(),
          ),
          GoRoute(
            path: AdminWebRoutes.food,
            builder: (c, s) => AdminFoodPage(
              initialEditId: s.uri.queryParameters['editId'],
            ),
          ),
          GoRoute(
            path: AdminWebRoutes.provinces,
            builder: (c, s) => AdminContentPage(
              config: AdminContentConfigs.province,
              initialEditId: s.uri.queryParameters['editId'],
            ),
          ),
          GoRoute(
            path: AdminWebRoutes.places,
            builder: (c, s) => AdminContentPage(
              config: AdminContentConfigs.place,
              initialEditId: s.uri.queryParameters['editId'],
            ),
          ),
          GoRoute(
            path: AdminWebRoutes.activities,
            builder: (c, s) => AdminContentPage(
              config: AdminContentConfigs.activity,
              initialEditId: s.uri.queryParameters['editId'],
            ),
          ),
          GoRoute(
            path: AdminWebRoutes.cultures,
            builder: (c, s) => AdminContentPage(
              config: AdminContentConfigs.culture,
              initialEditId: s.uri.queryParameters['editId'],
            ),
          ),
          GoRoute(
            path: AdminWebRoutes.localProducts,
            builder: (c, s) => AdminContentPage(
              config: AdminContentConfigs.localProduct,
              initialEditId: s.uri.queryParameters['editId'],
            ),
          ),
          GoRoute(
            path: AdminWebRoutes.popularApps,
            builder: (c, s) => const AdminPopularAppPage(),
          ),
          GoRoute(
            path: AdminWebRoutes.cfRetrain,
            builder: (c, s) => const AdminCfRetrainPage(),
          ),
          GoRoute(
            path: AdminWebRoutes.dataFreshness,
            builder: (c, s) => const AdminDataFreshnessPage(),
          ),
        ],
      ),
    ],
  );
}
