import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_repository.dart';
import 'theme.dart';
import '../features/item_detail/domain/detail_category.dart';
import '../features/item_detail/domain/item_detail_models.dart';

import '../features/home/presentation/home_page.dart';
import '../features/planner/presentation/business_location_page.dart';
import '../features/planner/data/models/trip_plan_response.dart';
import '../features/planner/data/trip_wizard_data.dart';
import '../features/planner/presentation/trip_planner_mock_data.dart';
import '../features/planner/presentation/trip_day_detail_page.dart';
import '../features/planner/presentation/trip_duration_page.dart';
import '../features/planner/presentation/trip_interest_page.dart';
import '../features/planner/presentation/trip_map_page.dart';
import '../features/planner/presentation/trip_planner_page.dart';
import '../features/planner/presentation/trip_result_page.dart';
import '../features/planner/presentation/saved_trips_page.dart';
import '../features/planner/presentation/trip_location_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/change_password_page.dart';
import '../features/profile/presentation/language_page.dart';
import '../features/profile/presentation/currency_page.dart';
import '../features/profile/presentation/wishlist_page.dart';
import '../features/profile/presentation/voucher_page.dart';
import '../features/profile/presentation/voucher_detail_page.dart';
import '../features/profile/presentation/rank_benefits_page.dart';
import '../features/profile/presentation/delete_user_data_page.dart';

import '../features/forum/presentation/forum_page.dart';
import '../features/forum/presentation/forum_profile_page.dart';
import '../features/forum/presentation/forum_notifications_page.dart';
import '../features/forum/presentation/create_post_page.dart';
import '../features/forum/presentation/forum_saved_posts_page.dart';
import '../features/forum/presentation/forum_report_post_page.dart';
import '../features/forum/presentation/thread_page.dart';
import '../features/popular_apps/presentation/popular_apps_page.dart';
import '../features/popular_apps/presentation/popular_apps_detail.dart';
import '../features/city_detail/domain/city_detail_models.dart';
import '../features/city_detail/presentation/city_detail_page.dart';
import '../features/feedback/presentation/feedback_page.dart';
import '../features/item_detail/presentation/activity_detail_page.dart';
import '../features/item_detail/presentation/culture_detail_page.dart';
import '../features/item_detail/presentation/food_detail_page.dart';
import '../features/item_detail/presentation/local_products_detail_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/explore/presentation/explore_search_page.dart';
import '../features/explore/presentation/explore_search_result_page.dart';
import '../features/explore/presentation/explore_category_page.dart';
import '../features/ai_search/presentation/ai_search_page.dart';
import '../features/notification/presentation/notification_page.dart';
import '../features/get_started/presentation/get_started_page.dart';
import '../features/translate/presentation/translate_page.dart';
import '../features/profile/presentation/upgrade_account_page.dart';
import '../features/profile/presentation/upgrade_payment_page.dart';
import '../features/recommend/presentation/recommend_page.dart';
import '../features/recommend/presentation/where/recommend_where_search_page.dart';
import '../features/recommend/presentation/when/recommend_when_calendar_page.dart';
import '../features/recommend/presentation/when/recommend_when_results_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import 'deep_link_state.dart';
import '../features/admin/presentation/admin_shell.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/admin_user_page.dart';
import '../features/admin/presentation/pages/admin_canned_replies_page.dart';
import '../features/admin/presentation/pages/admin_report_page.dart';
import '../features/admin/presentation/pages/admin_feedback_page.dart';
import '../features/admin/presentation/pages/admin_food_page.dart';
import '../features/admin/presentation/pages/admin_popular_app_page.dart';
import '../features/admin/presentation/pages/admin_cf_retrain_page.dart';
import '../features/personalization/data/travel_preferences_repository.dart';
import '../features/personalization/presentation/travel_preferences_onboarding_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const getStarted = '/get-started';
  static const home = '/home';
  static const tripPlanner = '/trip-planner';
  static const tripPlannerLocation = '/trip-planner/location';
  static const tripPlannerBusinessLocation = '/trip-planner/business-location';
  static const tripPlannerDuration = '/trip-planner/duration';
  static const tripPlannerInterest = '/trip-planner/interest';
  static const tripPlannerSaved = '/trip-planner/saved';
  static const tripPlannerResult = '/trip-planner/result';
  static const tripPlannerDayDetail = '/trip-planner/result/day/:dayIndex';
  static const tripPlannerMap =
      '/trip-planner/result/day/:dayIndex/map/:activityIndex';
  static const messages = '/messages';
  static const profile = '/profile';

  // Pages outside of the bottom navigation
  static const forum = '/forum';
  static const forumMe = '/forum/me';
  static const forumProfile = '/forum/profile/:authorId';
  static const forumNotifications = '/forum/notifications';
  static const forumSaved = '/forum/saved';
  static const forumCreate = '/forum/create';
  static const forumPost = '/forum/post/:postId';
  static const forumReport = '/forum/report/:postId';
  static const translate = '/translate';
  static const feedback = '/send-feedback';
  static const recommend = '/recommend';
  static const recommendWhereSearch = '/recommend/where-search';
  static const recommendWhenCalendar = '/recommend/when-calendar';
  static const recommendWhenResults = '/recommend/when-results';
  static const explore = '/explore';
  static const exploreSearch = '/explore-search';
  static const exploreSearchResult = '/explore-search-result';
  static const exploreCategory = '/explore-category';
  static const cityDetail = '/details/city';
  static const activityDetail = '/details/activities';
  static const cultureDetail = '/details/culture';
  static const foodDetail = '/details/food';
  static const localProductsDetail = '/details/local-products';
  static const popularApps = '/popular-apps';
  static const aiSearch = '/ai-search';
  static const wishlist = '/wishlist';
  static const voucher = '/voucher';
  static const voucherDetail = '/voucher-detail';
  static const rankBenefits = '/rank-benefits';
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
  static const travelPreferencesOnboarding = '/onboarding/travel-preferences';

  static String travelPreferencesOnboardingPath({String? returnTo}) {
    if (returnTo == null || returnTo.isEmpty) {
      return travelPreferencesOnboarding;
    }

    return Uri(
      path: travelPreferencesOnboarding,
      queryParameters: <String, String>{'returnTo': returnTo},
    ).toString();
  }

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

  // â”€â”€ Admin routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminCannedReplies = '/admin/canned-replies';
  static const adminReports = '/admin/reports';
  static const adminFeedback = '/admin/feedback';
  static const adminFood = '/admin/food';
  static const adminPopularApps = '/admin/popular-apps';
  static const adminCfRetrain = '/admin/cf-retrain';
  static const deleteUserData = '$profile/delete-user-data';

  static String forumPostPath(String postId) => '/forum/post/$postId';
  static String forumProfilePath(String authorId) => '/forum/profile/$authorId';
  static String forumReportPath(String postId) => '/forum/report/$postId';
  static String tripPlannerDayDetailPath(int dayIndex) =>
      '/trip-planner/result/day/$dayIndex';
  static String tripPlannerMapPath(int dayIndex, int activityIndex) =>
      '/trip-planner/result/day/$dayIndex/map/$activityIndex';
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.getStarted,
    refreshListenable: Listenable.merge(<Listenable>[
      AuthRepository.instance,
      TravelPreferencesRepository.instance,
    ]),
    redirect: (context, state) {
      final String location = state.matchedLocation;
      final bool loggedIn = AuthRepository.instance.isLoggedIn;
      final TravelPreferencesRepository preferencesRepository =
          TravelPreferencesRepository.instance;
      final bool isOnboardingRoute =
          location == AppRoutes.travelPreferencesOnboarding;
      final bool isAuthRoute =
          location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.forgotPassword;

      // Check if we should navigate to forgot password page (from deep link)
      if (shouldNavigateToForgotPassword()) {
        return AppRoutes.forgotPassword;
      }

      if (isOnboardingRoute && !loggedIn) {
        return AppRoutes.login;
      }

      if (!preferencesRepository.isReady) {
        return null;
      }

      if (loggedIn) {
        final bool needsPreferences =
            !preferencesRepository.hasCompletedCurrentUser;
        if (needsPreferences &&
            location != AppRoutes.travelPreferencesOnboarding) {
          return AppRoutes.travelPreferencesOnboarding;
        }

        if (!needsPreferences &&
            (location == AppRoutes.getStarted || isAuthRoute)) {
          return AppRoutes.home;
        }
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
        path: AppRoutes.forumMe,
        builder: (c, s) => const ForumProfilePage(authorId: 'me'),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumProfile,
        builder: (c, s) =>
            ForumProfilePage(authorId: s.pathParameters['authorId'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumNotifications,
        builder: (c, s) => const ForumNotificationsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumSaved,
        builder: (c, s) => const ForumSavedPostsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumCreate,
        builder: (c, s) => const CreatePostPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumPost,
        builder: (c, s) => ThreadPage(postId: s.pathParameters['postId'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumReport,
        builder: (c, s) =>
            ForumReportPostPage(postId: s.pathParameters['postId'] ?? ''),
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
        path: AppRoutes.translate,
        builder: (c, s) => const TranslatePage(),
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
        builder: (c, s) => const AiSearchPage(),
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
        path: AppRoutes.cityDetail,
        builder: (c, s) =>
            CityDetailPage(request: s.extra as CityDetailRequest),
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
        path: AppRoutes.travelPreferencesOnboarding,
        builder: (c, s) => TravelPreferencesOnboardingPage(
          returnRoute:
              s.uri.queryParameters['returnTo']?.trim().isNotEmpty == true
              ? s.uri.queryParameters['returnTo']!.trim()
              : AppRoutes.home,
        ),
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
            initialAvatarUrl: extra['avatarUrl'] as String?,
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
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.voucher,
        builder: (c, s) => const VoucherPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.voucherDetail,
        builder: (c, s) {
          final VoucherDetailPayload payload = s.extra is VoucherDetailPayload
              ? s.extra as VoucherDetailPayload
              : const VoucherDetailPayload(
                  isOwnedVoucher: false,
                  tag: 'Discount',
                  title: '\$5 off on orders over \$20',
                  pointsRequired: 5000,
                  availablePoints: 12500,
                  validityDays: 30,
                  voucherCode: 'SAVE5',
                  expiryDate: '30/04/2026',
                  descriptionLines: <String>[
                    'Special discount voucher for orders valued at \$20 or more',
                  ],
                  imageColorA: Color(0xFF5B6073),
                  imageColorB: Color(0xFF202736),
                );
          return VoucherDetailPage(payload: payload);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.rankBenefits,
        builder: (c, s) => const RankBenefitsPage(),
      ),
      // Ã¢â€â‚¬Ã¢â€â‚¬ Upgrade account flow Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

      // Ã¢â€â‚¬Ã¢â€â‚¬ Recommend flow Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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
        path: '${AppRoutes.popularApps}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PopularAppsDetailPage(appId: id);
        },
      ),
      // can highlight the active route without any extra state management.
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.adminDashboard,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminDashboardPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminUsers,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminUserPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminCannedReplies,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminCannedRepliesPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminReports,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminReportPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminFeedback,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminFeedbackPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminFood,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminFoodPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminPopularApps,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminPopularAppPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminCfRetrain,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminCfRetrainPage(),
            ),
          ),
        ],
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
                routes: [
                  GoRoute(
                    path: 'location',
                    builder: (context, state) => const TripLocationPage(),
                  ),
                  GoRoute(
                    path: 'business-location',
                    builder: (context, state) => const BusinessLocationPage(),
                  ),
                  GoRoute(
                    path: 'duration',
                    builder: (context, state) => TripDurationPage(
                      wizard: state.extra as TripWizardData?,
                    ),
                  ),
                  GoRoute(
                    path: 'interest',
                    builder: (context, state) => TripInterestPage(
                      wizard: state.extra as TripWizardData?,
                    ),
                  ),
                  GoRoute(
                    path: 'saved',
                    builder: (context, state) => const SavedTripsPage(),
                  ),
                  GoRoute(
                    path: 'result',
                    builder: (context, state) => TripResultPage(
                      plan: state.extra as TripPlanResponse?,
                    ),
                    routes: [
                      GoRoute(
                        path: 'day/:dayIndex',
                        builder: (context, state) => TripDayDetailPage(
                          dayIndex:
                              int.tryParse(
                                state.pathParameters['dayIndex'] ?? '',
                              ) ??
                              0,
                          dayData: state.extra as TripPlannerDayData?,
                        ),
                        routes: [
                          GoRoute(
                            path: 'map/:activityIndex',
                            builder: (context, state) => TripMapPage(
                              dayIndex:
                                  int.tryParse(
                                    state.pathParameters['dayIndex'] ?? '',
                                  ) ??
                                  0,
                              activityIndex:
                                  int.tryParse(
                                    state.pathParameters['activityIndex'] ?? '',
                                  ) ??
                                  0,
                              activity: state.extra as TripPlannerActivityData?,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
                routes: [
                  GoRoute(
                    path: 'delete-user-data',
                    builder: (context, state) => const DeleteUserDataPage(),
                  ),
                ],
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
/// saved-trips shortcut inline with other items.
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
      icon: Icons.bookmark_outline_rounded,
      selectedIcon: Icons.bookmark_rounded,
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
        context.push(AppRoutes.tripPlannerSaved);
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
        child: const Icon(
          Icons.bookmark_added_rounded,
          size: 26,
          color: Colors.white,
        ),
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
