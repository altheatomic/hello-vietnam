import 'package:go_router/go_router.dart';

import '../core/auth/auth_repository.dart';
import '../features/admin/presentation/admin_shell.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/admin_user_page.dart';
//import '../features/admin/presentation/pages/admin_canned_replies_page.dart';
import '../features/admin/presentation/pages/admin_report_page.dart';
import '../features/admin/presentation/pages/admin_feedback_page.dart';
import '../features/admin/presentation/pages/admin_food_page.dart';
import '../features/admin/presentation/pages/admin_popular_app_page.dart';
import '../features/admin/presentation/pages/admin_login_page.dart';
import '../features/admin/presentation/pages/admin_cf_retrain_page.dart';

class AdminRoutes {
  static const login = '/admin/login';
  static const dashboard = '/admin/dashboard';
  static const users = '/admin/users';
  //static const cannedReplies = '/admin/canned-replies';
  static const reports = '/admin/reports';
  static const feedback = '/admin/feedback';
  static const food = '/admin/food';
  static const popularApps = '/admin/popular-apps';
  static const cfRetrain = '/admin/cf-retrain';
}

GoRouter buildAdminRouter() {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AdminRoutes.login,
    redirect: (context, state) {
      // If user is not logged in, redirect to login
      if (!AuthRepository.instance.isLoggedIn) {
        return AdminRoutes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (c, s) => const AdminLoginPage(),
      ),
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
          //GoRoute(
          //  path: AdminRoutes.cannedReplies,
          //  builder: (c, s) => const AdminCannedRepliesPage(),
          //),
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
          GoRoute(
            path: AdminRoutes.cfRetrain,
            builder: (c, s) => const AdminCfRetrainPage(),
          ),
        ],
      ),
    ],
  );
}
