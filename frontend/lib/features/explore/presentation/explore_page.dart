import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/personalization/data/travel_preferences_repository.dart';
import 'package:hellovietnam/features/personalization/data/travel_recommendation_service.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:hellovietnam/features/personalization/presentation/widgets/travel_preferences_summary_card.dart';
import '../data/explore_mock_data.dart';
import '../domain/explore_item.dart';
import 'widgets/explore_floating_back_button.dart';
import 'widgets/explore_preview_widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _selectedFilter = 0;
  late final PageController _featuredController;

  /// Keys for each category section so we can scroll to them.
  final List<GlobalKey> _sectionKeys = List.generate(
    exploreCategories.length,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    _featuredController = PageController(viewportFraction: 0.42);
  }

  @override
  void dispose() {
    _featuredController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    setState(() => _selectedFilter = index);
    final keyContext = _sectionKeys[index].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.l10n;
    final statusBarH = MediaQuery.of(context).padding.top;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final UserTravelPreferences? preferences =
        TravelPreferencesRepository.instance.currentPreferences;
    final List<ExploreItem> featuredItems = preferences == null
        ? exploreFeatured
        : TravelRecommendationService.recommendedExploreItems(
            preferences,
          ).take(6).toList(growable: false);
    final List<ExploreCategory> orderedCategories = preferences == null
        ? exploreCategories
        : TravelRecommendationService.orderedExploreCategories(preferences);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Header with background image ────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Background image (15% opacity)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.15,
                        child: Image.asset(
                          AppConstants.exploreHeaderBgAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color:
                                    (isDark
                                            ? AppColors.primaryDark
                                            : AppColors.primaryLight)
                                        .withValues(alpha: 0.1),
                              ),
                        ),
                      ),
                    ),

                    // Header content
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppConstants.pagePadding,
                        statusBarH + 56,
                        AppConstants.pagePadding,
                        16,
                      ),
                      child: Column(
                        children: [
                          // Title (blue)
                          Text(
                            context.l10n.ui(
                              'Discover Vietnamese Culture and\nLocal Specialties',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primary,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 16),

                          SearchBarWidget(
                            hintText: strings.searchDestinations,
                            readOnly: true,
                            showFilterButton: false,
                            onTap: () => context.push(AppRoutes.exploreSearch),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              if (preferences != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: TravelPreferencesSummaryCard(
                      preferences: preferences,
                      onRetune: () => context.push(
                        AppRoutes.travelPreferencesOnboardingPath(
                          returnTo: AppRoutes.explore,
                        ),
                      ),
                      title: strings.exploreTunedTitle,
                      description: strings.exploreTunedDescription,
                      buttonLabel: strings.retune,
                    ),
                  ),
                ),

              // ── Featured suggestions (horizontal scroll) ────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 164,
                  child: PageView.builder(
                    controller: _featuredController,
                    physics: const BouncingScrollPhysics(
                      parent: PageScrollPhysics(),
                    ),
                    itemCount: featuredItems.length,
                    itemBuilder: (context, index) {
                      final item = featuredItems[index];
                      return AnimatedBuilder(
                        animation: _featuredController,
                        builder: (context, child) {
                          final page = _featuredController.hasClients
                              ? (_featuredController.page ??
                                    _featuredController.initialPage.toDouble())
                              : _featuredController.initialPage.toDouble();
                          final distance = (page - index).abs().clamp(0.0, 1.0);
                          final emphasis = (1 - distance).clamp(0.0, 1.0);

                          return Transform.scale(
                            scale: 0.9 + (emphasis * 0.1),
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: Offset(0, 10 - (emphasis * 10)),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: index == 0
                                      ? AppConstants.pagePadding
                                      : 6,
                                  right: index == featuredItems.length - 1
                                      ? AppConstants.pagePadding
                                      : 6,
                                ),
                                child: _FeaturedCard(
                                  item: item,
                                  emphasis: emphasis,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Sticky filter chips ─────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  categories: orderedCategories,
                  selectedIndex: _selectedFilter,
                  onTap: _scrollToSection,
                ),
              ),

              // ── All categories on one page ───────────────────
              ...List.generate(orderedCategories.length, (i) {
                final category = orderedCategories[i];
                return SliverToBoxAdapter(
                  child: _CategorySection(
                    key: _sectionKeys[i],
                    category: category,
                    categoryIndex: i,
                  ),
                );
              }),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
          ExploreFloatingBackButton(onTap: _handleBack),
        ],
      ),
    );
  }
}

// ─── Sticky filter delegate ──────────────────────────────────────────

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final List<ExploreCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  _StickyFilterDelegate({
    required this.categories,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  double get minExtent => 126;
  @override
  double get maxExtent => 126;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: (isDark ? const Color(0xFF020B10) : Colors.white).withValues(
        alpha: isDark ? 0.92 : 1,
      ),
      padding: EdgeInsets.only(top: statusBarH + 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.pagePadding,
              ),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                final Color activeColor = isDark
                    ? AppColors.primaryLight
                    : AppColors.primary;
                final Color inactiveColor = isDark
                    ? const Color(0xFFA9BCC7)
                    : Colors.grey;
                return GestureDetector(
                  onTap: () => onTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? activeColor : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.exploreCategoryLabel(categories[index].id),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) =>
      selectedIndex != oldDelegate.selectedIndex ||
      categories != oldDelegate.categories;
}

// ─── Featured suggestion card ────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, this.emphasis = 1});

  final ExploreItem item;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Color.lerp(
      (isDark ? Colors.white : Colors.white).withValues(
        alpha: isDark ? 0.14 : 0.55,
      ),
      AppColors.primaryLight.withValues(alpha: 0.95),
      emphasis,
    )!;
    final shadowColor = Color.lerp(
      Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
      AppColors.primary.withValues(alpha: 0.18),
      emphasis,
    )!;

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.detailPathForCategory(item.category),
          extra: ItemDetailRequest(
            id: item.id,
            name: item.name,
            category: item.category,
            fallbackImages: <String>[item.imagePath],
            fallbackImagePath: item.imagePath,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.2 + emphasis),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16 + (emphasis * 14),
              offset: Offset(0, 8 + (emphasis * 6)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExplorePreviewImage(imagePath: item.imagePath, borderRadius: 22),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.58),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    context.l10n.ui(item.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category section ────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    super.key,
    required this.category,
    required this.categoryIndex,
  });
  final ExploreCategory category;
  final int categoryIndex;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        12,
        AppConstants.pagePadding,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description + Explore button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.l10n.ui(category.description),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFD6E7EF) : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  context.push(AppRoutes.exploreCategory, extra: categoryIndex);
                },
                child: Text(
                  context.l10n.ui('Explore'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2-column grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: category.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              return _ExploreItemCard(item: category.items[index]);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Single explore item card ────────────────────────────────────────

class _ExploreItemCard extends StatelessWidget {
  const _ExploreItemCard({required this.item});
  final ExploreItem item;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.detailPathForCategory(item.category),
          extra: ItemDetailRequest(
            id: item.id,
            name: item.name,
            category: item.category,
            fallbackImages: <String>[item.imagePath],
            fallbackImagePath: item.imagePath,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: isDark ? const Color(0xFF102A36) : Colors.grey.shade200,
              child: Icon(
                Icons.image_outlined,
                size: 36,
                color: isDark ? AppColors.primaryLight : Colors.grey.shade400,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  context.l10n.ui(item.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
