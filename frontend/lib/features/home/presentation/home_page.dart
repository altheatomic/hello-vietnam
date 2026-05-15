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
import '../data/home_mock_data.dart';
import 'widgets/home_banner.dart';
import 'widgets/feature_grid.dart';
import 'widgets/recommendation_section.dart';
import 'widgets/recommendation_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
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

                const SizedBox(height: 4),

                // ── Best Destination ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RecommendationSection(
                    title: 'Best Destination',
                    backgroundImage: AppConstants.destinationBgAsset,
                    children: mockDestinations.map((d) {
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
                    children: mockDishes.map((d) {
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
