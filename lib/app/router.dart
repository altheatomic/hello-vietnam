import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_repository.dart';
import 'theme.dart';
import '../features/item_detail/domain/detail_category.dart';
import '../features/item_detail/domain/item_detail_models.dart';

import '../features/home/presentation/home_page.dart';
import '../features/planner/presentation/trip_planner_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/change_password_page.dart';
import '../features/profile/presentation/language_page.dart';
import '../features/profile/presentation/currency_page.dart';
import '../features/profile/presentation/wishlist_page.dart';

import '../features/forum/presentation/forum_page.dart';
import '../features/popular_apps/presentation/popular_apps_page.dart';
import '../features/popular_apps/presentation/popular_apps_detail.dart';
import '../features/feedback/presentation/feedback_page.dart';
import '../features/item_detail/presentation/activity_detail_page.dart';
import '../features/item_detail/presentation/culture_detail_page.dart';
import '../features/item_detail/presentation/food_detail_page.dart';
import '../features/item_detail/presentation/local_products_detail_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/explore/presentation/explore_search_page.dart';
import '../features/explore/presentation/explore_search_result_page.dart';
import '../features/explore/presentation/explore_category_page.dart';
import '../features/notification/presentation/notification_page.dart';
import '../features/get_started/presentation/get_started_page.dart';
import '../features/profile/presentation/upgrade_account_page.dart';
import '../features/profile/presentation/upgrade_payment_page.dart';
import '../features/recommend/domain/recommend_destination.dart';
import '../features/recommend/presentation/recommend_page.dart';
import '../features/recommend/presentation/where/recommend_where_search_page.dart';
import '../features/recommend/presentation/where/recommend_where_detail_page.dart';
import '../features/recommend/presentation/when/recommend_when_calendar_page.dart';
import '../features/recommend/presentation/when/recommend_when_results_page.dart';
import '../features/recommend/presentation/when/recommend_when_detail_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../main.dart'; // Import to access shouldNavigateToForgotPassword

final rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const getStarted = '/get-started';
  static const home = '/home';
  static const tripPlanner = '/trip-planner';
  static const messages = '/messages';
  static const profile = '/profile';

  // Pages outside of the bottom navigation
  static const forum = '/forum';
  static const phrases = '/popular-phrases';
  static const feedback = '/send-feedback';
  static const recommend = '/recommend';
  static const recommendWhereSearch = '/recommend/where-search';
  static const recommendWhereDetail = '/recommend/where-detail';
  static const recommendWhenCalendar = '/recommend/when-calendar';
  static const recommendWhenResults = '/recommend/when-results';
  static const recommendWhenDetail = '/recommend/when-detail';
  static const explore = '/explore';
  static const exploreSearch = '/explore-search';
  static const exploreSearchResult = '/explore-search-result';
  static const exploreCategory = '/explore-category';
  static const activityDetail = '/details/activities';
  static const cultureDetail = '/details/culture';
  static const foodDetail = '/details/food';
  static const localProductsDetail = '/details/local-products';
  static const popularApps = '/popular-apps';
  static const aiSearch = '/ai-search';
  static const wishlist = '/wishlist';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const notification = '/notification';
  static const upgradeAccount = '/upgrade-account';
  static const upgradePayment = '/upgrade-payment';
  static const editProfile = '/edit-profile';
  static const changePassword = '/change-password';
  static const language = '/language';
  static const currency = '/currency';

  static String detailPathForCategory(DetailCategory category) {
    switch (category) {
      case DetailCategory.activities:
        return activityDetail;
      case DetailCategory.culture:
        return cultureDetail;
      case DetailCategory.food:
        return foodDetail;
      case DetailCategory.localProducts:
        return localProductsDetail;
    }
  }
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.getStarted,
    redirect: (context, state) {
      // Check if we should navigate to forgot password page (from deep link)
      if (shouldNavigateToForgotPassword()) {
        return AppRoutes.forgotPassword;
      }
      return null; // No redirect
    },
    routes: [
      // Routes outside of bottom navigation.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.getStarted,
        builder: (c, s) => const GetStartedPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forum,
        builder: (c, s) => const ForumPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.popularApps,
        builder: (c, s) => const PopularAppsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.feedback,
        builder: (c, s) => const FeedbackPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.explore,
        builder: (c, s) => const ExplorePage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.exploreSearch,
        builder: (c, s) => const ExploreSearchPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.aiSearch,
        builder: (c, s) => const ExploreSearchPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.exploreSearchResult,
        builder: (c, s) =>
            ExploreSearchResultPage(destination: s.extra as String? ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.exploreCategory,
        builder: (c, s) =>
            ExploreCategoryPage(initialTab: s.extra as int? ?? 0),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.activityDetail,
        builder: (c, s) =>
            ActivityDetailPage(request: s.extra as ItemDetailRequest),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.cultureDetail,
        builder: (c, s) =>
            CultureDetailPage(request: s.extra as ItemDetailRequest),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.foodDetail,
        builder: (c, s) =>
            FoodDetailPage(request: s.extra as ItemDetailRequest),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.localProductsDetail,
        builder: (c, s) =>
            LocalProductsDetailPage(request: s.extra as ItemDetailRequest),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.login,
        builder: (c, s) => const LoginPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.register,
        builder: (c, s) => const RegisterPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forgotPassword,
        builder: (c, s) => const ForgotPasswordPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.notification,
        builder: (c, s) => const NotificationPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.editProfile,
        builder: (c, s) {
          final Map<String, dynamic> extra =
              (s.extra as Map<String, dynamic>?) ?? <String, dynamic>{};
          return EditProfilePage(
            initialEmail: (extra['email'] as String?) ?? 'thangtoi@gmail.com',
            initialUsername: (extra['username'] as String?) ?? 'AnhLaThangToi',
            initialAvatarIndex: (extra['avatarIndex'] as int?) ?? 0,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.changePassword,
        builder: (c, s) => const ChangePasswordPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.language,
        builder: (c, s) => const LanguagePage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.currency,
        builder: (c, s) => const CurrencyPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.wishlist,
        builder: (c, s) => const WishlistPage(),
      ),
      // ── Upgrade account flow ────────────────────────────────
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.upgradeAccount,
        builder: (c, s) => const UpgradeAccountPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.upgradePayment,
        builder: (c, s) =>
            UpgradePaymentPage(planId: (s.extra as String?) ?? '1m'),
      ),

      // ── Recommend flow ──────────────────────────────────────
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommend,
        builder: (c, s) => const RecommendPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommendWhereSearch,
        builder: (c, s) =>
            RecommendWhereSearchPage(initialQuery: (s.extra as String?) ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommendWhereDetail,
        builder: (c, s) => RecommendWhereDetailPage(
          destination: s.extra as RecommendDestination,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommendWhenCalendar,
        builder: (c, s) => const RecommendWhenCalendarPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommendWhenResults,
        builder: (c, s) =>
            RecommendWhenResultsPage(dateRange: s.extra as DateTimeRange),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommendWhenDetail,
        builder: (c, s) => RecommendWhenDetailPage(
          destination: s.extra as RecommendDestination,
        ),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${AppRoutes.popularApps}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PopularAppsDetailPage(appId: id);
        },
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tripPlanner,
                builder: (context, state) => const TripPlannerPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => const ForumPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _ScaffoldWithBottomNav extends StatelessWidget {
  const _ScaffoldWithBottomNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    // Profile tab (index 3): redirect to login if not authenticated
    if (index == 3 && !AuthRepository.instance.isLoggedIn) {
      context.push(AppRoutes.login);
      return;
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
      ),
    );
  }
}

/// Custom bottom navigation bar with rounded top corners and a center
/// search button inline with other items.
class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: 'Trip Planner',
    ),
    _NavItem(
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
      label: '',
    ), // center
    _NavItem(
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      label: 'Forum',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              if (i == 2) return _buildCenterButton(context);
              final branchIndex = i < 2 ? i : i - 1;
              final isSelected = branchIndex == currentIndex;
              return _buildNavItem(
                _items[i],
                isSelected,
                () => onTap(branchIndex),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isSelected, VoidCallback onTap) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(AppRoutes.exploreSearch);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.search_rounded, size: 26, color: Colors.white),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
