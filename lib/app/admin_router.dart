import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_shell.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/admin_user_page.dart';
import '../features/admin/presentation/pages/admin_canned_replies_page.dart';
import '../features/admin/presentation/pages/admin_report_page.dart';
import '../features/admin/presentation/pages/admin_feedback_page.dart';
import '../features/admin/presentation/pages/admin_food_page.dart';
import '../features/admin/presentation/pages/admin_popular_app_page.dart';

class AdminRoutes {
  static const dashboard = '/admin/dashboard';
  static const users = '/admin/users';
  static const cannedReplies = '/admin/canned-replies';
  static const reports = '/admin/reports';
  static const feedback = '/admin/feedback';
  static const food = '/admin/food';
  static const popularApps = '/admin/popular-apps';
}

GoRouter buildAdminRouter() {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AdminRoutes.dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AdminRoutes.dashboard,
            builder: (c, s) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: AdminRoutes.users,
            builder: (c, s) => const AdminUserPage(),
          ),
          GoRoute(
            path: AdminRoutes.cannedReplies,
            builder: (c, s) => const AdminCannedRepliesPage(),
          ),
          GoRoute(
            path: AdminRoutes.reports,
            builder: (c, s) => const AdminReportPage(),
          ),
          GoRoute(
            path: AdminRoutes.feedback,
            builder: (c, s) => const AdminFeedbackPage(),
          ),
          GoRoute(
            path: AdminRoutes.food,
            builder: (c, s) => const AdminFoodPage(),
          ),
          GoRoute(
            path: AdminRoutes.popularApps,
            builder: (c, s) => const AdminPopularAppPage(),
          ),
        ],
      ),
    ],
  );
}
