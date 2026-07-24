import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_repository.dart';
import '../core/language/app_language.dart';
import 'theme.dart';
import '../features/item_detail/domain/detail_category.dart';
import '../features/item_detail/domain/item_detail_models.dart';
import '../features/profile/data/wishlist_repository.dart';

import '../features/home/presentation/home_page.dart';
import '../features/planner/presentation/business_location_page.dart';
import '../features/planner/data/models/trip_plan_response.dart';
import '../features/planner/data/trip_wizard_data.dart';
import '../features/planner/presentation/trip_budget_page.dart';
import '../features/planner/presentation/trip_day_detail_page.dart';
import '../features/planner/presentation/trip_duration_page.dart';
import '../features/planner/presentation/trip_interest_page.dart';
import '../features/planner/presentation/trip_map_page.dart';
import '../features/planner/presentation/trip_planner_mock_data.dart';
import '../features/planner/presentation/trip_planner_page.dart';
import '../features/planner/presentation/widgets/trip_result_loader.dart';
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
import '../features/loyalty/presentation/loyalty_page.dart';

import '../features/forum/presentation/forum_page.dart';
import '../features/forum/presentation/forum_profile_page.dart';
import '../features/forum/presentation/create_post_page.dart';
import '../features/forum/data/forum_store.dart';
import '../features/forum/domain/create_forum_post_request.dart';
import '../features/forum/domain/forum_models.dart';
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
import '../features/explore/domain/explore_province.dart';
import '../features/ai_search/data/ai_recognition_history_repository.dart';
import '../features/ai_search/presentation/ai_recognition_history_page.dart';
import '../features/ai_search/presentation/ai_search_page.dart';
import '../features/ai_chat/presentation/ai_chat_history_page.dart';
import '../features/ai_chat/presentation/ai_chat_page.dart';
import '../features/notification/presentation/notification_page.dart';
import '../features/notification/presentation/notification_settings_page.dart';
import '../features/get_started/presentation/get_started_page.dart';
import '../features/translate/presentation/translate_page.dart';
import '../features/profile/presentation/upgrade_account_page.dart';
import '../features/profile/presentation/upgrade_payment_page.dart';
import '../features/recommend/presentation/where/recommend_where_search_page.dart';
import '../features/recommend/presentation/when/recommend_when_calendar_page.dart';
import '../features/recommend/presentation/when/recommend_when_results_page.dart';
import '../features/recommend/presentation/recommended_place_detail_page.dart';
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
import '../features/admin/presentation/pages/admin_content_page.dart';
import '../features/admin/presentation/pages/admin_popular_app_page.dart';
import '../features/admin/presentation/pages/admin_cf_retrain_page.dart';
import '../features/admin/domain/admin_content.dart';
import '../features/personalization/data/travel_preferences_repository.dart';
import '../features/personalization/presentation/travel_preferences_onboarding_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

String? _pendingAuthReturnTo;
Object? _pendingTripPlannerExtra;

String? _validTripPlannerReturnTo(String? value) {
  final String candidate = value?.trim() ?? '';
  if (candidate.isEmpty) return null;
  final Uri? uri = Uri.tryParse(candidate);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return uri.path == AppRoutes.tripPlanner ||
          uri.path.startsWith('${AppRoutes.tripPlanner}/')
      ? uri.toString()
      : null;
}

String _loginPathWithReturnTo(String returnTo) => Uri(
  path: AppRoutes.login,
  queryParameters: <String, String>{'returnTo': returnTo},
).toString();

ExploreProvince parseExploreSearchResultExtra(Object? extra) {
  if (extra is ExploreProvince) {
    return extra;
  }
  if (extra is Map<String, dynamic>) {
    return ExploreProvince.fromJson(extra);
  }
  if (extra is Map) {
    return ExploreProvince.fromJson(
      extra.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }
  if (extra is String) {
    return ExploreProvince.unresolved(extra);
  }
  return ExploreProvince.unresolved('');
}

TripWizardData? _tripWizardFromExtra(Object? extra) {
  final Object? value = extra ?? _takePendingTripPlannerExtra();
  if (value is TripWizardData) return value;
  if (value is Map<String, dynamic>) return TripWizardData.fromJson(value);
  if (value is Map) {
    return TripWizardData.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

TripPlanResponse? _tripPlanFromExtra(Object? extra) {
  final Object? value = extra ?? _takePendingTripPlannerExtra();
  return value is TripPlanResponse ? value : null;
}

Object? _takePendingTripPlannerExtra() {
  final Object? value = _pendingTripPlannerExtra;
  _pendingTripPlannerExtra = null;
  return value;
}

CityDetailRequest _cityDetailRequest(GoRouterState state) {
  final Map<String, String> query = state.uri.queryParameters;
  if (query['id'] != null && query['name'] != null) {
    return CityDetailRequest(
      id: query['id']!,
      name: query['name']!,
      fallbackImages: _stringListFromQuery(query['images']),
      fallbackImagePath: query['image'],
      fallbackRating: double.tryParse(query['rating'] ?? ''),
    );
  }
  return state.extra as CityDetailRequest;
}

ItemDetailRequest _itemDetailRequest(
  GoRouterState state,
  DetailCategory category,
) {
  final Map<String, String> query = state.uri.queryParameters;
  if (query['id'] != null && query['name'] != null) {
    return ItemDetailRequest(
      id: query['id']!,
      name: query['name']!,
      category: category,
      fallbackImages: _stringListFromQuery(query['images']),
      fallbackImagePath: query['image'],
      favoriteType: FavoriteType.tryParse(query['favoriteType'] ?? ''),
      trackExploreBehavior: query['trackExplore'] == 'true',
      exploreProvinceId: query['provinceId'],
    );
  }
  return state.extra as ItemDetailRequest;
}

List<String> _stringListFromQuery(String? value) {
  if (value == null || value.isEmpty) return const <String>[];
  final Object? decoded = jsonDecode(value);
  return decoded is List
      ? decoded.whereType<String>().toList(growable: false)
      : const <String>[];
}

DateTimeRange<DateTime> _dateRange(GoRouterState state) {
  final String? start = state.uri.queryParameters['start'];
  final String? end = state.uri.queryParameters['end'];
  if (start != null && end != null) {
    return DateTimeRange<DateTime>(
      start: DateTime.parse(start),
      end: DateTime.parse(end),
    );
  }
  return state.extra as DateTimeRange<DateTime>;
}

class AppRoutes {
  static const getStarted = '/get-started';
  static const home = '/home';
  static const tripPlanner = '/trip-planner';
  static const tripPlannerLocation = '/trip-planner/location';
  static const tripPlannerBusinessLocation = '/trip-planner/business-location';
  static const tripPlannerDuration = '/trip-planner/duration';
  static const tripPlannerInterest = '/trip-planner/interest';
  static const tripPlannerBudget = '/trip-planner/budget';
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
  static const forumSaved = '/forum/saved';
  static const forumCreate = '/forum/create';
  static const forumPost = '/forum/post/:postId';
  static const forumEdit = '/forum/post/:postId/edit';
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
  static const recommendedPlaceDetail = '/details/recommended-place';
  static const activityDetail = '/details/activities';
  static const cultureDetail = '/details/culture';
  static const foodDetail = '/details/food';
  static const localProductsDetail = '/details/local-products';
  static const popularApps = '/popular-apps';
  static const aiSearch = '/ai-search';
  static const aiSearchHistory = '/ai-search/history';
  static const aiChat = '/ai-chat';
  static const aiChatHistory = '/ai-chat/history';
  static const wishlist = '/wishlist';
  static const voucher = '/voucher';
  static const loyalty = '/loyalty';
  static const voucherDetail = '/voucher-detail';
  static const rankBenefits = '/rank-benefits';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const notification = '/notification';
  static const notificationSettings = '/notification/settings';
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

  static String cityDetailPath(CityDetailRequest request) => Uri(
    path: cityDetail,
    queryParameters: <String, String>{
      'id': request.id,
      'name': request.name,
      if (request.fallbackImages.isNotEmpty)
        'images': jsonEncode(request.fallbackImages),
      if (request.fallbackImagePath != null)
        'image': request.fallbackImagePath!,
      if (request.fallbackRating != null)
        'rating': request.fallbackRating!.toString(),
    },
  ).toString();

  static String recommendedPlaceDetailPath({
    required String idProvince,
    required String idPlace,
  }) => Uri(
    path: recommendedPlaceDetail,
    queryParameters: <String, String>{
      'idProvince': idProvince,
      'idPlace': idPlace,
    },
  ).toString();

  static String itemDetailPath(ItemDetailRequest request) => Uri(
    path: detailPathForCategory(request.category),
    queryParameters: <String, String>{
      'id': request.id,
      'name': request.name,
      if (request.fallbackImages.isNotEmpty)
        'images': jsonEncode(request.fallbackImages),
      if (request.fallbackImagePath != null)
        'image': request.fallbackImagePath!,
      if (request.favoriteType != null)
        'favoriteType': request.favoriteType!.dbValue,
      if (request.trackExploreBehavior) 'trackExplore': 'true',
      if (request.exploreProvinceId != null)
        'provinceId': request.exploreProvinceId!,
    },
  ).toString();

  static String recommendWhenResultsPath(DateTimeRange<DateTime> range) => Uri(
    path: recommendWhenResults,
    queryParameters: <String, String>{
      'start': range.start.toIso8601String(),
      'end': range.end.toIso8601String(),
    },
  ).toString();

  /// Builds a restorable result location for a persisted plan, or marks the
  /// location as a process-local draft when [idPlan] is absent.
  static String tripPlannerResultPath({String? idPlan}) {
    final String normalizedId = idPlan?.trim() ?? '';
    return Uri(
      path: tripPlannerResult,
      queryParameters: <String, String>{
        if (normalizedId.isNotEmpty) 'idPlan': normalizedId,
        if (normalizedId.isEmpty) 'draft': 'true',
      },
    ).toString();
  }

  // â”€â”€ Admin routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminCannedReplies = '/admin/canned-replies';
  static const adminReports = '/admin/reports';
  static const adminFeedback = '/admin/feedback';
  static const adminFood = '/admin/food';
  static const adminProvinces = '/admin/provinces';
  static const adminPlaces = '/admin/places';
  static const adminActivities = '/admin/activities';
  static const adminCultures = '/admin/cultures';
  static const adminLocalProducts = '/admin/local-products';
  static const adminPopularApps = '/admin/popular-apps';
  static const adminCfRetrain = '/admin/cf-retrain';
  static const manageUploadedMedia = '$profile/manage-uploaded-media';
  static const deleteUserData = '$profile/delete-user-data';

  static String forumPostPath(String postId) => '/forum/post/$postId';
  static String forumEditPath(String postId) => '/forum/post/$postId/edit';
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
    onException: (BuildContext context, GoRouterState state, GoRouter router) {
      final String? deepLinkLocation = appRouteLocationFromDeepLink(state.uri);
      if (deepLinkLocation != null) {
        router.go(deepLinkLocation);
        return;
      }
      router.go(AppRoutes.home);
    },
    refreshListenable: Listenable.merge(<Listenable>[
      AuthRepository.instance,
      TravelPreferencesRepository.instance,
      DeepLinkState.instance,
    ]),
    redirect: (context, state) {
      final String? directDeepLinkLocation = appRouteLocationFromDeepLink(
        state.uri,
      );
      if (directDeepLinkLocation != null) {
        return directDeepLinkLocation;
      }

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
      final bool isTripPlannerRoute =
          location == AppRoutes.tripPlanner ||
          location.startsWith('${AppRoutes.tripPlanner}/');

      if (isTripPlannerRoute && !loggedIn) {
        final String returnTo = state.uri.toString();
        _pendingAuthReturnTo = returnTo;
        _pendingTripPlannerExtra = state.extra;
        return _loginPathWithReturnTo(returnTo);
      }

      // Check if we should navigate to forgot password page (from deep link)
      if (shouldNavigateToForgotPassword()) {
        return AppRoutes.forgotPassword;
      }

      final String? upgradePaymentLocation = consumeUpgradePaymentDeepLink();
      if (upgradePaymentLocation != null) {
        return upgradePaymentLocation;
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
        final String? authReturnTo = _validTripPlannerReturnTo(
          state.uri.queryParameters['returnTo'],
        );
        final String? returnTo = authReturnTo ?? _pendingAuthReturnTo;
        if (needsPreferences &&
            !preferencesRepository.hasDeferredCurrentUserOnboarding &&
            location != AppRoutes.travelPreferencesOnboarding) {
          return AppRoutes.travelPreferencesOnboardingPath(returnTo: returnTo);
        }

        if (!needsPreferences && returnTo != null) {
          _pendingAuthReturnTo = null;
          return returnTo;
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
        redirect: (context, state) => AppRoutes.messages,
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
        path: AppRoutes.forumSaved,
        builder: (c, s) => const ForumSavedPostsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumCreate,
        builder: (c, s) {
          final CreateForumPostRequest request =
              s.extra is CreateForumPostRequest
              ? s.extra as CreateForumPostRequest
              : const CreateForumPostRequest();
          return CreatePostPage(request: request);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumPost,
        builder: (c, s) => ThreadPage(postId: s.pathParameters['postId'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forumEdit,
        builder: (BuildContext context, GoRouterState state) {
          final String postId = state.pathParameters['postId'] ?? '';
          final ForumPost? post = state.extra is ForumPost
              ? state.extra as ForumPost
              : ForumStore.instance.postById(postId);
          if (post == null) {
            return ThreadPage(postId: postId);
          }
          return CreatePostPage(editingPost: post);
        },
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
        builder: (c, s) => AiSearchPage(
          initialHistoryEntry: s.extra is AiRecognitionHistoryEntry
              ? s.extra! as AiRecognitionHistoryEntry
              : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.aiSearchHistory,
        builder: (c, s) => const AiRecognitionHistoryPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.aiChat,
        builder: (c, s) =>
            AiChatPage(conversationId: s.uri.queryParameters['conversationId']),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.aiChatHistory,
        builder: (c, s) => const AiChatHistoryPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.exploreSearchResult,
        builder: (c, s) {
          final ExploreProvince province = parseExploreSearchResultExtra(
            s.extra,
          );
          return ExploreSearchResultPage(selectedProvince: province);
        },
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
        builder: (c, s) => CityDetailPage(request: _cityDetailRequest(s)),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommendedPlaceDetail,
        builder: (c, s) => RecommendedPlaceDetailPage(
          idProvince: s.uri.queryParameters['idProvince'] ?? '',
          idPlace: s.uri.queryParameters['idPlace'] ?? '',
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.activityDetail,
        builder: (c, s) => ActivityDetailPage(
          request: _itemDetailRequest(s, DetailCategory.activities),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.cultureDetail,
        builder: (c, s) => CultureDetailPage(
          request: _itemDetailRequest(s, DetailCategory.culture),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.foodDetail,
        builder: (c, s) =>
            FoodDetailPage(request: _itemDetailRequest(s, DetailCategory.food)),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.localProductsDetail,
        builder: (c, s) => LocalProductsDetailPage(
          request: _itemDetailRequest(s, DetailCategory.localProducts),
        ),
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
        path: AppRoutes.notificationSettings,
        builder: (c, s) => const NotificationSettingsPage(),
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
        builder: (c, s) => CurrencyPage(),
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
        path: AppRoutes.loyalty,
        builder: (c, s) => const LoyaltyPage(),
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
        builder: (c, s) => UpgradePaymentPage(
          planId: s.uri.queryParameters['plan'] ?? (s.extra as String?) ?? '1m',
          checkoutSessionId: s.uri.queryParameters['stripe_session_id'],
        ),
      ),

      // Ã¢â€â‚¬Ã¢â€â‚¬ Recommend flow Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.recommend,
        redirect: (c, s) => AppRoutes.recommendWhereSearch,
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
        builder: (c, s) => RecommendWhenResultsPage(dateRange: _dateRange(s)),
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
            path: AppRoutes.adminProvinces,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminContentPage(
                config: AdminContentConfigs.province,
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminPlaces,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminContentPage(config: AdminContentConfigs.place),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminActivities,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminContentPage(
                config: AdminContentConfigs.activity,
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminCultures,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminContentPage(
                config: AdminContentConfigs.culture,
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminLocalProducts,
            pageBuilder: (c, s) => NoTransitionPage<void>(
              key: s.pageKey,
              child: const AdminContentPage(
                config: AdminContentConfigs.localProduct,
              ),
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
          return _ScaffoldWithBottomNav(
            navigationShell: navigationShell,
            currentPath: state.uri.path,
          );
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
                      wizard: _tripWizardFromExtra(state.extra),
                    ),
                  ),
                  GoRoute(
                    path: 'interest',
                    builder: (context, state) => TripInterestPage(
                      wizard: _tripWizardFromExtra(state.extra),
                    ),
                  ),
                  GoRoute(
                    path: 'budget',
                    builder: (context, state) => TripBudgetPage(
                      wizard: _tripWizardFromExtra(state.extra),
                    ),
                  ),
                  GoRoute(
                    path: 'saved',
                    builder: (context, state) => const SavedTripsPage(),
                  ),
                  GoRoute(
                    path: 'result',
                    builder: (context, state) => TripResultLoader(
                      idPlan: state.uri.queryParameters['idPlan'],
                      draft: _tripPlanFromExtra(state.extra),
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
                          dayData: state.extra is TripPlannerDayData
                              ? state.extra as TripPlannerDayData
                              : null,
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
                              activity: state.extra is TripPlannerActivityData
                                  ? state.extra as TripPlannerActivityData
                                  : null,
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
                    path: 'manage-uploaded-media',
                    builder: (context, state) => const DeleteUserDataPage(),
                  ),
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
  const _ScaffoldWithBottomNav({
    required this.navigationShell,
    required this.currentPath,
  });

  final StatefulNavigationShell navigationShell;
  final String currentPath;

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
        currentPath: currentPath,
        onTap: (index) => _onTap(context, index),
      ),
    );
  }
}

/// Custom bottom navigation bar with rounded top corners and a center
/// saved-trips shortcut inline with other items.
class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav({
    required this.currentIndex,
    required this.currentPath,
    required this.onTap,
  });

  final int currentIndex;
  final String currentPath;
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
      label: 'Planner',
    ),
    _NavItem(
      icon: Icons.bookmark_outline_rounded,
      selectedIcon: Icons.bookmark_added_rounded,
      label: 'Saved',
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(34);
    const EdgeInsets navPadding = EdgeInsets.symmetric(horizontal: 14);
    final Color shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.36)
        : Colors.black.withValues(alpha: 0.10);
    final int selectedVisualIndex = _selectedVisualIndex;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              blurRadius: 28,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? <Color>[
                          const Color(0xE6102530),
                          const Color(0xB80A1A22),
                        ]
                      : <Color>[
                          Colors.white.withValues(alpha: 0.76),
                          const Color(0xDDEFF9FF),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.11)
                      : Colors.white.withValues(alpha: 0.72),
                  width: 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double availableWidth =
                      constraints.maxWidth - navPadding.horizontal;
                  final double slotWidth = availableWidth / _items.length;
                  final double indicatorWidth = (slotWidth - 14)
                      .clamp(54.0, 68.0)
                      .toDouble();

                  return Padding(
                    padding: navPadding,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: selectedVisualIndex.toDouble(),
                            end: selectedVisualIndex.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          builder:
                              (
                                BuildContext context,
                                double value,
                                Widget? child,
                              ) {
                                return Transform.translate(
                                  offset: Offset(
                                    (value * slotWidth) +
                                        ((slotWidth - indicatorWidth) / 2),
                                    0,
                                  ),
                                  child: child,
                                );
                              },
                          child: _NavSelectionIndicator(
                            width: indicatorWidth,
                            isDark: isDark,
                          ),
                        ),
                        Row(
                          children: List.generate(_items.length, (i) {
                            final int? branchIndex = _branchIndexForVisual(i);
                            final bool isSelected = i == selectedVisualIndex;
                            return Expanded(
                              child: _buildNavItem(
                                context,
                                _items[i],
                                isSelected,
                                branchIndex == null
                                    ? () =>
                                          context.go(AppRoutes.tripPlannerSaved)
                                    : () => onTap(branchIndex),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    _NavItem item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected
        ? AppColors.primaryLight
        : isDark
        ? const Color(0xFF9BB7C5)
        : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                key: ValueKey<IconData>(
                  isSelected ? item.selectedIcon : item.icon,
                ),
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.ui(item.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  int get _selectedVisualIndex {
    if (currentPath == AppRoutes.tripPlannerSaved) {
      return 2;
    }

    return currentIndex < 2 ? currentIndex : currentIndex + 1;
  }

  int? _branchIndexForVisual(int visualIndex) {
    if (visualIndex == 2) {
      return null;
    }

    return visualIndex < 2 ? visualIndex : visualIndex - 1;
  }
}

class _NavSelectionIndicator extends StatelessWidget {
  const _NavSelectionIndicator({required this.width, required this.isDark});

  final double width;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  AppColors.primaryLight.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ]
              : <Color>[
                  AppColors.primary.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.70),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.primary.withValues(alpha: 0.10),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.10),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
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
