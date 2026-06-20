import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/personalization/data/travel_preferences_repository.dart';
import 'package:hellovietnam/features/personalization/data/travel_recommendation_service.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:hellovietnam/features/personalization/presentation/widgets/travel_preferences_summary_card.dart';
import 'package:hellovietnam/features/recommend/domain/recommend_destination.dart';
import '../data/home_repository.dart';
import '../data/home_mock_data.dart';
import '../domain/destination.dart';
import '../domain/dish.dart';
import 'widgets/active_trip_card.dart';
import 'widgets/home_banner.dart';
import 'widgets/feature_grid.dart';
import 'widgets/recommendation_section.dart';
import 'widgets/recommendation_card.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeRepository _homeRepository = HomeRepository();
  List<Destination> _destinations = mockDestinations;
  List<Dish> _dishes = mockDishes;

  @override
  void initState() {
    super.initState();
    _loadFeaturedContent();
  }

  Future<void> _viewPlan(ActiveTrip trip) async {
    final idPlan = trip.idPlan;
    if (idPlan == null) {
      context.push(
        AppRoutes.tripPlannerDayDetailPath(trip.relevantActivity.dayIndex),
      );
      return;
    }
    try {
      final plan = await TripRepository().getPlan(idPlan);
      if (!mounted) return;
      context.push(AppRoutes.tripPlannerResult, extra: plan);
    } catch (_) {
      if (!mounted) return;
      context.push(
        AppRoutes.tripPlannerDayDetailPath(trip.relevantActivity.dayIndex),
      );
    }
  }

  Future<void> _loadFeaturedContent() async {
    try {
      final HomeFeaturedContent content = await _homeRepository
          .fetchFeaturedContent();
      if (!mounted) return;
      setState(() {
        if (content.destinations.isNotEmpty) {
          _destinations = content.destinations;
        }
        if (content.dishes.isNotEmpty) {
          _dishes = content.dishes;
        }
      });
    } catch (_) {
      // Keep bundled fallback cards when Supabase has no public read policy yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final bottomContentPadding = mediaQuery.padding.bottom + 96;
    final size = mediaQuery.size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFFF1F6FE),
                    Color(0xFFDFF5FF),
                    Color(0xFFCCF6F1),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: _HomeDecorativeOrb(
              size: 230,
              color: const Color(0x662BC3FF),
            ),
          ),
          Positioned(
            top: size.height * 0.3,
            left: -80,
            child: _HomeDecorativeOrb(
              size: 210,
              color: const Color(0x5532D2FF),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -55,
            child: _HomeDecorativeOrb(
              size: 180,
              color: const Color(0x5556E2D5),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomContentPadding),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Blue header section ────────────────────
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.pagePadding,
                    statusBarHeight + 12,
                    AppConstants.pagePadding,
                    20,
                  ),
                  child: Column(
                    children: [
                      // App bar row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hello Vietnam',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentGold,
                            ),
                          ),
                          ListenableBuilder(
                            listenable: MockNotificationRepository.instance,
                            builder: (BuildContext context, Widget? child) {
                              final int unreadCount = MockNotificationRepository
                                  .instance
                                  .unreadCount;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.notifications_outlined,
                                        size: 22,
                                      ),
                                      color: Colors.white,
                                      onPressed: () =>
                                          context.push(AppRoutes.notification),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.2,
                                          ),
                                          boxShadow: const <BoxShadow>[
                                            BoxShadow(
                                              color: Color(0x22000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Search bar
                      SearchBarWidget(
                        hintText: 'Search for destinations',
                        readOnly: true,
                        showFilterButton: false,
                        onTap: () => context.push(AppRoutes.exploreSearch),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Active trip card (shown only when a trip is in progress) ──
                ListenableBuilder(
                  listenable: TripStore.instance,
                  builder: (context, _) {
                    final trip = TripStore.instance.activeTrip;
                    if (trip == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.pagePadding,
                        0,
                        AppConstants.pagePadding,
                        16,
                      ),
                      child: ActiveTripCard(
                        trip: trip,
                        onViewOrRoute: () => _viewPlan(trip),
                        onEnd: TripStore.instance.endTrip,
                      ),
                    );
                  },
                ),

                // ── Banner ───────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.pagePadding,
                  ),
                  child: HomeBanner(),
                ),

                const SizedBox(height: 28),

                // ── Feature grid (8 buttons) ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.pagePadding,
                  ),
                  child: FeatureGrid(items: homeFeatures),
                ),

                const SizedBox(height: 20),

                ListenableBuilder(
                  listenable: TravelPreferencesRepository.instance,
                  builder: (BuildContext context, Widget? child) {
                    final UserTravelPreferences? preferences =
                        TravelPreferencesRepository.instance.currentPreferences;
                    if (preferences == null) {
                      return const SizedBox.shrink();
                    }

                    final List<RecommendDestination> destinations =
                        TravelRecommendationService.recommendedDestinations(
                          preferences,
                        ).take(4).toList(growable: false);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.pagePadding,
                      ),
                      child: Column(
                        children: <Widget>[
                          TravelPreferencesSummaryCard(
                            preferences: preferences,
                            onRetune: () => context.push(
                              AppRoutes.travelPreferencesOnboardingPath(
                                returnTo: AppRoutes.home,
                              ),
                            ),
                            buttonLabel: 'Retune',
                          ),
                          const SizedBox(height: 18),
                          RecommendationSection(
                            title: 'Picked For You',
                            backgroundImage: AppConstants.destinationBgAsset,
                            height: 290,
                            children: destinations
                                .map((RecommendDestination d) {
                                  return RecommendationCard(
                                    name: d.name,
                                    category: d.tags.join(' · '),
                                    rating: d.rating,
                                    imagePath: d.imagePath,
                                    isFavorite: false,
                                    onTap: () {
                                      context.push(
                                        AppRoutes.cityDetail,
                                        extra: CityDetailRequest(
                                          id: d.id,
                                          name: d.name,
                                          fallbackImages: <String>[
                                            d.imagePath,
                                            ...d.gallery,
                                          ],
                                          fallbackImagePath: d.imagePath,
                                          fallbackRating: d.rating,
                                        ),
                                      );
                                    },
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),

                // ── Best Destination ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RecommendationSection(
                    title: 'Best Destination',
                    backgroundImage: AppConstants.destinationBgAsset,
                    children: _destinations.map((d) {
                      return RecommendationCard(
                        name: d.name,
                        category: d.category,
                        rating: d.rating,
                        imagePath: d.imagePath,
                        isFavorite: d.isFavorite,
                        onTap: () {
                          context.push(
                            AppRoutes.cityDetail,
                            extra: CityDetailRequest(
                              id: d.id,
                              name: d.name,
                              fallbackImages: <String>[d.imagePath],
                              fallbackImagePath: d.imagePath,
                              fallbackRating: d.rating,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Best Dishes ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RecommendationSection(
                    title: 'Best Dishes',
                    backgroundImage: AppConstants.dishesBgAsset,
                    children: _dishes.map((d) {
                      return RecommendationCard(
                        name: d.name,
                        category: d.category,
                        rating: d.rating,
                        imagePath: d.imagePath,
                        isFavorite: d.isFavorite,
                        onTap: () {
                          context.push(
                            AppRoutes.detailPathForCategory(
                              DetailCategory.food,
                            ),
                            extra: ItemDetailRequest(
                              id: d.id,
                              name: d.name,
                              category: DetailCategory.food,
                              fallbackImages: <String>[d.imagePath],
                              fallbackImagePath: d.imagePath,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeDecorativeOrb extends StatelessWidget {
  const _HomeDecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                color,
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
