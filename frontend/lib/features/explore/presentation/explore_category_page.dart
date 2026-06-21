import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/profile/data/wishlist_controller.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import '../data/explore_search_results_data.dart';
import 'widgets/explore_floating_back_button.dart';
import 'widgets/explore_preview_widgets.dart';

const List<String> _filterLabels = [
  'ACTIVITIES',
  'CULTURE',
  'FOOD',
  'LOCAL PRODUCTS',
];

/// Explore category page — shows all items across Vietnam (no specific city).
/// Accessed from the "Explore" button in the main explore page.
class ExploreCategoryPage extends StatefulWidget {
  /// Which tab to open first (0 = Activities, 1 = Culture, …).
  final int initialTab;

  const ExploreCategoryPage({super.key, this.initialTab = 0});

  @override
  State<ExploreCategoryPage> createState() => _ExploreCategoryPageState();
}

class _ExploreCategoryPageState extends State<ExploreCategoryPage> {
  static const int _pageSize = 2;

  late int _selectedFilter;
  late final DestinationResults _results;
  late final ScrollController _scrollController;
  int _visibleItemCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialTab;
    // General Vietnam results (no specific city).
    _results = getResultsForDestination('vietnam');
    _scrollController = ScrollController()..addListener(_handleScroll);
    _resetPagination();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<SearchResultItem> items = _results.byCategory(_selectedFilter);
    final int visibleCount = items.length < _visibleItemCount
        ? items.length
        : _visibleItemCount;
    final bool hasMore = visibleCount < items.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    60,
                    statusBarH + 8,
                    AppConstants.pagePadding,
                    4,
                  ),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface.withValues(alpha: 0.92)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(45),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(
                          alpha: isDark ? 0.18 : 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          Icons.search_rounded,
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vietnam',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Sticky filter chips ────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  selectedIndex: _selectedFilter,
                  onTap: (i) => setState(() {
                    _selectedFilter = i;
                    _resetPagination();
                  }),
                ),
              ),

              // ── Result cards ───────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  10,
                  AppConstants.pagePadding,
                  24,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ResultCard(
                      item: items[index],
                      category: _categoryForIndex(_selectedFilter),
                    ),
                    childCount: visibleCount,
                  ),
                ),
              ),
              if (hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
          ExploreFloatingBackButton(onTap: () => context.pop()),
        ],
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 280) return;
    _loadMore();
  }

  void _loadMore() {
    final int total = _results.byCategory(_selectedFilter).length;
    if (_visibleItemCount >= total) return;

    setState(() {
      _visibleItemCount = (_visibleItemCount + _pageSize).clamp(0, total);
    });
  }

  void _resetPagination() {
    final int total = _results.byCategory(_selectedFilter).length;
    _visibleItemCount = total < _pageSize ? total : _pageSize;
  }
}

DetailCategory _categoryForIndex(int index) {
  switch (index) {
    case 1:
      return DetailCategory.culture;
    case 2:
      return DetailCategory.food;
    case 3:
      return DetailCategory.localProducts;
    case 0:
    default:
      return DetailCategory.activities;
  }
}

// ─── Shared sticky filter delegate ───────────────────────────────────

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  _StickyFilterDelegate({required this.selectedIndex, required this.onTap});

  @override
  double get minExtent => 82;
  @override
  double get maxExtent => 82;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: (isDark ? const Color(0xFF020B10) : Colors.white).withValues(
            alpha: isDark ? 0.78 : 0.86,
          ),
          padding: EdgeInsets.only(
            top: statusBarH > 0 ? statusBarH : 0,
            bottom: 8,
            left: 0,
            right: 0,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.pagePadding,
            ),
            itemCount: _filterLabels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isSelected = index == selectedIndex;
              return Center(
                child: _AppleFilterChip(
                  label: context.l10n.ui(_filterLabels[index]),
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) =>
      selectedIndex != oldDelegate.selectedIndex;
}

class _AppleFilterChip extends StatelessWidget {
  const _AppleFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedScale(
      scale: isSelected ? 1 : 0.98,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: 46,
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF7FD8FF),
                        AppColors.primary,
                        Color(0xFF2FB7E7),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        (isDark ? const Color(0xFF102A36) : Colors.white)
                            .withValues(alpha: isDark ? 0.86 : 0.96),
                        (isDark
                                ? const Color(0xFF173746)
                                : const Color(0xFFF3FBFF))
                            .withValues(alpha: isDark ? 0.80 : 0.92),
                      ],
                    ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.48)
                    : AppColors.primaryLight.withValues(
                        alpha: isDark ? 0.16 : 0.36,
                      ),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isSelected
                      ? AppColors.primaryDark.withValues(alpha: 0.22)
                      : (isDark ? Colors.black : AppColors.primary).withValues(
                          alpha: isDark ? 0.22 : 0.07,
                        ),
                  blurRadius: isSelected ? 18 : 14,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.7),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFFC6D7DF)
                          : const Color(0xFF667085)),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Result card with carousel ───────────────────────────────────────

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.item, required this.category});

  final SearchResultItem item;
  final DetailCategory category;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  late final PageController _imageController;
  final WishlistController _wishlistController = WishlistController.instance;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _wishlistController.ensureLoaded();
  }

  Future<void> _toggleFavorite() async {
    try {
      final bool? result = await _wishlistController.toggleFavorite(
        type: _favoriteTypeForCategory(widget.category),
        rawItemId: widget.item.id,
        fallbackName: widget.item.name,
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

  FavoriteType _favoriteTypeForCategory(DetailCategory category) {
    switch (category) {
      case DetailCategory.activities:
        return FavoriteType.activity;
      case DetailCategory.culture:
        return FavoriteType.culture;
      case DetailCategory.food:
        return FavoriteType.food;
      case DetailCategory.localProducts:
        return FavoriteType.localProduct;
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.item.images.length;
    final Color titleColor = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.detailPathForCategory(widget.category),
          extra: ItemDetailRequest(
            id: widget.item.id,
            name: widget.item.name,
            category: widget.category,
            fallbackImages: widget.item.images,
            fallbackImagePath: widget.item.images.isEmpty
                ? null
                : widget.item.images.first,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _imageController,
                      physics: const BouncingScrollPhysics(
                        parent: PageScrollPhysics(),
                      ),
                      itemCount: imageCount,
                      itemBuilder: (context, i) {
                        return AnimatedBuilder(
                          animation: _imageController,
                          builder: (context, child) {
                            final page = _imageController.hasClients
                                ? (_imageController.page ??
                                      _imageController.initialPage.toDouble())
                                : _imageController.initialPage.toDouble();
                            final distance = (page - i).abs().clamp(0.0, 1.0);
                            final emphasis = (1 - distance).clamp(0.0, 1.0);

                            return Transform.scale(
                              scale: 0.94 + (emphasis * 0.06),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.06 + (emphasis * 0.16),
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: ExplorePreviewImage(
                            imagePath: widget.item.images[i],
                            borderRadius: 16,
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: _wishlistController,
                        builder: (BuildContext context, Widget? child) {
                          final bool isFavorite = _wishlistController
                              .isFavorite(
                                type: _favoriteTypeForCategory(widget.category),
                                rawItemId: widget.item.id,
                              );
                          return GestureDetector(
                            onTap: _toggleFavorite,
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? AppColors.primary
                                  : Colors.white,
                              size: 24,
                            ),
                          );
                        },
                      ),
                    ),
                    if (imageCount > 1)
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: ExploreLiquidDots(
                          controller: _imageController,
                          itemCount: imageCount,
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.ui(widget.item.name),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
