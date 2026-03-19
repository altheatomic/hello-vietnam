import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
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
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                          onPressed: () {
                            // TODO: navigate to notifications
                          },
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

            const SizedBox(height: 12),

            // ── Best Destination ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: RecommendationSection(
                title: 'Best Destination',
                backgroundImage: AppConstants.destinationBgUrl,
                children: mockDestinations.map((d) {
                  return RecommendationCard(
                    name: d.name,
                    category: d.category,
                    rating: d.rating,
                    imagePath: d.imagePath,
                    isFavorite: d.isFavorite,
                    onTap: () {
                      context.push(
                        AppRoutes.detailPathForCategory(DetailCategory.culture),
                        extra: ItemDetailRequest(
                          id: d.id,
                          name: d.name,
                          category: DetailCategory.culture,
                          fallbackImages: <String>[d.imagePath],
                          fallbackImagePath: d.imagePath,
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // ── Best Dishes ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: RecommendationSection(
                title: 'Best Dishes',
                backgroundImage: AppConstants.dishesBgUrl,
                children: mockDishes.map((d) {
                  return RecommendationCard(
                    name: d.name,
                    category: d.category,
                    rating: d.rating,
                    imagePath: d.imagePath,
                    isFavorite: d.isFavorite,
                    onTap: () {
                      context.push(
                        AppRoutes.detailPathForCategory(DetailCategory.food),
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

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
