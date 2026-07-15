import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'widgets/admin_page_container.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_topbar.dart';

/// Root layout widget for the admin web shell.
///
/// Composes the three structural zones:
///   [AdminSidebar]  |  [AdminTopBar]
///                   |  [AdminPageContainer → child]
///
/// Receives [child] from the go_router ShellRoute — whichever admin page
/// matches the current URL is rendered inside [AdminPageContainer].
///
/// [currentPath] is supplied by the ShellRoute builder via GoRouterState.uri.path
/// and forwarded to the sidebar (active highlight) and topbar (page title).
///
/// NOTE: This widget is intentionally separate from AppScaffold. AppScaffold
/// is mobile-first (status-bar padding, back button, primaryLight header band)
/// and would require invasive changes to work on desktop. AdminShell is a
/// clean parallel that shares the same theme tokens but not the same structure.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  /// Maps each admin route to its display title shown in [AdminTopBar].
  static const Map<String, String> _pageTitles = {
    '/admin/dashboard': 'Dashboard',
    '/admin/users': 'User Manager',
    //'/admin/canned-replies': 'Canned Replies',
    '/admin/reports': 'Reports',
    '/admin/food': 'Food Management',
    '/admin/provinces': 'Province Management',
    '/admin/places': 'Place Management',
    '/admin/activities': 'Activity Management',
    '/admin/cultures': 'Culture Management',
    '/admin/local-products': 'Local Product Management',
    '/admin/cf-retrain': 'CF Model Retrain',
  };

  String get _title {
    for (final entry in _pageTitles.entries) {
      if (currentPath == entry.key || currentPath.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppColors.background provides the #F5FAFF base that AdminPageContainer
      // extends; using it here prevents any flash of white behind the sidebar.
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Fixed-width sidebar — never scrolls
          AdminSidebar(currentPath: currentPath),

          // Right column: topbar fixed at top, page content scrolls below
          Expanded(
            child: Column(
              children: [
                AdminTopBar(title: _title),
                Expanded(child: AdminPageContainer(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
