import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
import 'package:hellovietnam/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/location/presentation/quick_location_flow.dart';
import 'package:hellovietnam/features/notification/application/notification_inbox_controller.dart';
import 'package:hellovietnam/features/personalization/data/travel_preferences_repository.dart';
import 'package:hellovietnam/features/personalization/data/travel_recommendation_service.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:hellovietnam/features/personalization/presentation/widgets/travel_preferences_summary_card.dart';
import 'package:hellovietnam/features/profile/data/wishlist_controller.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final HomeRepository _homeRepository = HomeRepository();
  final QuickLocationFlow _quickLocationFlow = QuickLocationFlow();
  late final AnimationController _galaxyTwinkleController;
  List<Destination> _destinations = mockDestinations;
  List<Dish> _dishes = mockDishes;

  @override
  void initState() {
    super.initState();
    _galaxyTwinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _loadFeaturedContent();
  }

  @override
  void dispose() {
    _galaxyTwinkleController.dispose();
    super.dispose();
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
    final AppStrings strings = context.l10n;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final bottomContentPadding = mediaQuery.padding.bottom + 96;
    final size = mediaQuery.size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF020B10) : Colors.white,
              ),
            ),
          ),
          if (isDark) ...<Widget>[
            Positioned(
              top: -90,
              right: -70,
              child: _HomeDecorativeOrb(
                size: 230,
                color: const Color(0x5532C7FF),
              ),
            ),
            Positioned(
              top: size.height * 0.3,
              left: -80,
              child: _HomeDecorativeOrb(
                size: 210,
                color: const Color(0x334DB8E8),
              ),
            ),
            Positioned(
              bottom: 120,
              right: -55,
              child: _HomeDecorativeOrb(
                size: 180,
                color: const Color(0x3347E0D0),
              ),
            ),
          ],
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const <Color>[
                              Color(0xFF020713),
                              Color(0xFF05152C),
                              Color(0xFF082A43),
                              Color(0xFF03171D),
                            ]
                          : const <Color>[
                              Color(0xFF69C9F1),
                              AppColors.primary,
                              Color(0xFF36D5C7),
                            ],
                      stops: isDark
                          ? const <double>[0.0, 0.38, 0.72, 1.0]
                          : null,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.22),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.10 : 0.42,
                        ),
                      ),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: <Widget>[
                      if (isDark)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _GalaxyHeaderPainter(
                                twinkle: _galaxyTwinkleController,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppConstants.pagePadding,
                          statusBarHeight + 12,
                          AppConstants.pagePadding,
                          20,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Hello Vietnam',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? const Color(0xFFFFDFA3)
                                          : AppColors.accentGold,
                                      letterSpacing: 0,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color:
                                              (isDark
                                                      ? const Color(0xFF9B6DFF)
                                                      : AppColors.primaryDark)
                                                  .withValues(
                                                    alpha: isDark ? 0.28 : 0.22,
                                                  ),
                                          blurRadius: isDark ? 16 : 12,
                                          offset: const Offset(0, 4),
                                        ),
                                        if (isDark)
                                          Shadow(
                                            color: const Color(
                                              0xFF4DDFFF,
                                            ).withValues(alpha: 0.18),
                                            blurRadius: 22,
                                            offset: const Offset(0, 6),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ListenableBuilder(
                                  listenable:
                                      NotificationInboxController.instance,
                                  builder: (BuildContext context, Widget? child) {
                                    final int unreadCount =
                                        NotificationInboxController
                                            .instance
                                            .unreadCount;

                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        _HomeHeaderIconButton(
                                          icon: Icons.place_outlined,
                                          semanticLabel: 'Set location',
                                          onPressed: () =>
                                              _quickLocationFlow.start(context),
                                        ),
                                        const SizedBox(width: 8),
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: <Widget>[
                                            _HomeHeaderIconButton(
                                              icon:
                                                  Icons.notifications_outlined,
                                              semanticLabel: 'Notifications',
                                              onPressed: () => context.push(
                                                AppRoutes.notification,
                                              ),
                                            ),
                                            if (unreadCount > 0)
                                              Positioned(
                                                top: -3,
                                                right: -3,
                                                child: Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 18,
                                                        minHeight: 18,
                                                      ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFF3B30,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                    boxShadow:
                                                        const <BoxShadow>[
                                                          BoxShadow(
                                                            color: Color(
                                                              0x26000000,
                                                            ),
                                                            blurRadius: 10,
                                                            offset: Offset(
                                                              0,
                                                              4,
                                                            ),
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      height: 1,
                                                      letterSpacing: 0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
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
                              hintText: strings.searchDestinations,
                              readOnly: true,
                              showFilterButton: false,
                              onTap: () =>
                                  context.push(AppRoutes.exploreSearch),
                            ),
                          ],
                        ),
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
                        onViewOrRoute: () {
                          final int dayIndex =
                              trip.relevantActivity.dayIndex;
                          context.push(
                            AppRoutes.tripPlannerDayDetailPath(dayIndex),
                            extra: trip.days[dayIndex],
                          );
                        },
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

                const SizedBox(height: 16),

                // ── Feature grid (8 buttons) ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.pagePadding,
                  ),
                  child: FeatureGrid(items: homeFeatures),
                ),

                const SizedBox(height: 12),

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
                            buttonLabel: strings.retune,
                          ),
                          const SizedBox(height: 18),
                          RecommendationSection(
                            title: strings.pickedForYou,
                            backgroundImage: AppConstants.destinationBgAsset,
                            height: 290,
                            children: destinations
                                .map((RecommendDestination d) {
                                  return _FavoriteRecommendationCard(
                                    favoriteType: FavoriteType.city,
                                    rawItemId: d.id,
                                    fallbackName: d.name,
                                    name: d.name,
                                    category: d.tags.join(' · '),
                                    rating: d.rating,
                                    imagePath: d.imagePath,
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

                const SizedBox(height: 20),

                // ── Best Destination ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RecommendationSection(
                    title: strings.bestDestination,
                    backgroundImage: AppConstants.destinationBgAsset,
                    children: _destinations.map((d) {
                      return _FavoriteRecommendationCard(
                        favoriteType: FavoriteType.city,
                        rawItemId: d.id,
                        fallbackName: d.name,
                        name: d.name,
                        category: d.category,
                        rating: d.rating,
                        imagePath: d.imagePath,
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
                    title: strings.bestDishes,
                    backgroundImage: AppConstants.dishesBgAsset,
                    children: _dishes.map((d) {
                      return _FavoriteRecommendationCard(
                        favoriteType: FavoriteType.food,
                        rawItemId: d.id,
                        fallbackName: d.name,
                        name: d.name,
                        category: d.category,
                        rating: d.rating,
                        imagePath: d.imagePath,
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
          const Positioned.fill(child: AiChatHomeLauncher()),
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

class _GalaxyHeaderPainter extends CustomPainter {
  const _GalaxyHeaderPainter({required Animation<double> twinkle})
    : _twinkle = twinkle,
      super(repaint: twinkle);

  final Animation<double> _twinkle;

  static const List<_HeaderStar> _stars = <_HeaderStar>[
    _HeaderStar(0.12, 0.18, 0.9, 0.45, false),
    _HeaderStar(0.18, 0.34, 1.3, 0.68, true),
    _HeaderStar(0.27, 0.14, 0.8, 0.46, false),
    _HeaderStar(0.38, 0.26, 1.6, 0.82, true),
    _HeaderStar(0.49, 0.17, 0.9, 0.48, false),
    _HeaderStar(0.58, 0.36, 1.2, 0.64, true),
    _HeaderStar(0.67, 0.20, 0.7, 0.46, false),
    _HeaderStar(0.78, 0.48, 1.5, 0.78, true),
    _HeaderStar(0.87, 0.30, 0.9, 0.52, false),
    _HeaderStar(0.22, 0.62, 0.8, 0.44, false),
    _HeaderStar(0.45, 0.58, 1.1, 0.58, false),
    _HeaderStar(0.61, 0.66, 1.4, 0.72, true),
    _HeaderStar(0.76, 0.68, 0.8, 0.48, false),
    _HeaderStar(0.90, 0.62, 0.7, 0.42, false),
  ];

  static const List<_NebulaGlow> _nebula = <_NebulaGlow>[
    _NebulaGlow(0.46, -0.08, 0.26, 0x6644D7FF),
    _NebulaGlow(0.42, 0.18, 0.30, 0x5A177CFF),
    _NebulaGlow(0.51, 0.40, 0.34, 0x6B0C8DFF),
    _NebulaGlow(0.48, 0.66, 0.28, 0x5A21A7FF),
    _NebulaGlow(0.58, 0.86, 0.24, 0x4D49EED0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = _twinkle.value * math.pi * 2;
    final Rect rect = Offset.zero & size;

    final Paint depthPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.12, -0.22),
        radius: 1.1,
        colors: <Color>[Color(0x2200E5FF), Color(0x00000713)],
      ).createShader(rect);
    canvas.drawRect(rect, depthPaint);

    canvas.save();
    canvas.translate(-size.width * 0.05, -size.height * 0.18);
    canvas.rotate(-0.12);
    for (final _NebulaGlow glow in _nebula) {
      final Offset center = Offset(glow.x * size.width, glow.y * size.height);
      final double radius = glow.radius * size.width;
      final Rect glowRect = Rect.fromCircle(center: center, radius: radius);
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Color(glow.color),
            Color(glow.color).withValues(alpha: 0.22),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.42, 1.0],
        ).createShader(glowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, radius, glowPaint);
    }
    canvas.restore();

    final Paint dustPaint = Paint();
    for (int i = 0; i < 118; i += 1) {
      final double x = _unitNoise(i, 11) * size.width;
      final double y = _unitNoise(i, 29) * size.height;
      final double inNebula = (1 - ((x / size.width) - 0.48).abs() * 2.2).clamp(
        0.0,
        1.0,
      );
      final double radius = 0.35 + _unitNoise(i, 47) * (0.75 + inNebula * 0.35);
      final double alpha = 0.22 + _unitNoise(i, 71) * (0.42 + inNebula * 0.22);
      dustPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, dustPaint);
    }

    final Paint blueDustPaint = Paint();
    for (int i = 0; i < 36; i += 1) {
      final double x = (0.33 + _unitNoise(i, 83) * 0.34) * size.width;
      final double y = _unitNoise(i, 101) * size.height;
      final double radius = 0.6 + _unitNoise(i, 127) * 1.5;
      blueDustPaint
        ..color = const Color(
          0xFF4E9CFF,
        ).withValues(alpha: 0.16 + _unitNoise(i, 151) * 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
      canvas.drawCircle(Offset(x, y), radius * 2.0, blueDustPaint);
      blueDustPaint.maskFilter = null;
      canvas.drawCircle(Offset(x, y), radius * 0.5, blueDustPaint);
    }

    for (int i = 0; i < _stars.length; i += 1) {
      final _HeaderStar star = _stars[i];
      final Offset point = Offset(star.x * size.width, star.y * size.height);
      final double pulse = star.twinkles
          ? (0.5 + 0.5 * math.sin(phase + i * 1.7))
          : 0.0;
      final double radius =
          star.radius * (star.twinkles ? 1.0 + pulse * 0.72 : 1);
      final double alpha = star.alpha + (star.twinkles ? pulse * 0.24 : 0);
      final Paint glowPaint = Paint()
        ..color = const Color(0xFFEAFBFF).withValues(alpha: alpha * 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + pulse * 3);
      final Paint starPaint = Paint()
        ..color = (i.isEven ? Colors.white : const Color(0xFFBEEFFF))
            .withValues(alpha: alpha.clamp(0.0, 0.90));

      canvas.drawCircle(point, radius * 3.1, glowPaint);
      canvas.drawCircle(point, radius, starPaint);

      if (star.twinkles) {
        final Paint rayPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.20)
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round;
        final double ray = radius * (3.2 + pulse);
        canvas.drawLine(
          point.translate(-ray, 0),
          point.translate(ray, 0),
          rayPaint,
        );
        canvas.drawLine(
          point.translate(0, -ray),
          point.translate(0, ray),
          rayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyHeaderPainter oldDelegate) => false;
}

class _NebulaGlow {
  const _NebulaGlow(this.x, this.y, this.radius, this.color);

  final double x;
  final double y;
  final double radius;
  final int color;
}

class _HeaderStar {
  const _HeaderStar(this.x, this.y, this.radius, this.alpha, this.twinkles);

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final bool twinkles;
}

double _unitNoise(int seed, int salt) {
  final double value =
      math.sin((seed + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return value - value.floorToDouble();
}

class _HomeHeaderIconButton extends StatelessWidget {
  const _HomeHeaderIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 25),
        tooltip: semanticLabel,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          hoverColor: Colors.white.withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _FavoriteRecommendationCard extends StatefulWidget {
  const _FavoriteRecommendationCard({
    required this.favoriteType,
    required this.rawItemId,
    required this.fallbackName,
    required this.name,
    required this.category,
    required this.rating,
    required this.imagePath,
    required this.onTap,
  });

  final FavoriteType favoriteType;
  final String rawItemId;
  final String fallbackName;
  final String name;
  final String category;
  final double rating;
  final String imagePath;
  final VoidCallback onTap;

  @override
  State<_FavoriteRecommendationCard> createState() =>
      _FavoriteRecommendationCardState();
}

class _FavoriteRecommendationCardState
    extends State<_FavoriteRecommendationCard> {
  final WishlistController _controller = WishlistController.instance;

  @override
  void initState() {
    super.initState();
    _controller.ensureLoaded();
  }

  Future<void> _toggleFavorite() async {
    try {
      final bool? result = await _controller.toggleFavorite(
        type: widget.favoriteType,
        rawItemId: widget.rawItemId,
        fallbackName: widget.fallbackName,
      );
      if (!mounted || result != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to update wishlist.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update wishlist failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return RecommendationCard(
          name: widget.name,
          category: widget.category,
          rating: widget.rating,
          imagePath: widget.imagePath,
          isFavorite: _controller.isFavorite(
            type: widget.favoriteType,
            rawItemId: widget.rawItemId,
          ),
          onTap: widget.onTap,
          onFavoriteTap: _toggleFavorite,
        );
      },
    );
  }
}
