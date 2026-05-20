import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
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
  late int _selectedFilter;
  late final DestinationResults _results;
  final WishlistRepository _wishlistRepository = WishlistRepository();
  final Set<String> _favoriteFoodIds = <String>{};
  final Set<String> _favoritePlaceIds = <String>{};
  final Set<String> _favoriteActivityIds = <String>{};
  final Set<String> _favoriteCultureIds = <String>{};
  final Set<String> _favoriteLocalProductIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialTab;
    // General Vietnam results (no specific city).
    _results = getResultsForDestination('vietnam');
    _syncFavoritesFromWishlist();
  }

  Future<void> _syncFavoritesFromWishlist() async {
    final userId = AuthRepository.instance.user?.id;
    if (userId == null) return;
    try {
      final items = await _wishlistRepository.fetchWishlist();
      if (!mounted) return;
      setState(() {
        _favoriteFoodIds
          ..clear()
          ..addAll(
            items
                .where((item) => item.type == FavoriteType.food)
                .map((item) => item.id),
          );
        _favoritePlaceIds
          ..clear()
          ..addAll(
            items
                .where((item) => item.type == FavoriteType.place)
                .map((item) => item.id),
          );
        _favoriteActivityIds
          ..clear()
          ..addAll(
            items
                .where((item) => item.type == FavoriteType.activity)
                .map((item) => item.id),
          );
        _favoriteCultureIds
          ..clear()
          ..addAll(
            items
                .where((item) => item.type == FavoriteType.culture)
                .map((item) => item.id),
          );
        _favoriteLocalProductIds
          ..clear()
          ..addAll(
            items
                .where((item) => item.type == FavoriteType.localProduct)
                .map((item) => item.id),
          );
      });
    } catch (_) {}
  }

  bool _isFavoriteForCurrentFilter(SearchResultItem item) {
    switch (_categoryForIndex(_selectedFilter)) {
      case DetailCategory.activities:
        return _favoriteActivityIds.contains(item.id);
      case DetailCategory.culture:
        return _favoriteCultureIds.contains(item.id);
      case DetailCategory.food:
        return _favoriteFoodIds.contains(item.id);
      case DetailCategory.localProducts:
        return _favoriteLocalProductIds.contains(item.id);
    }
  }

  void _onFavoriteChanged(SearchResultItem item, bool isFavorite) {
    setState(() {
      final targetSet = switch (_categoryForIndex(_selectedFilter)) {
        DetailCategory.activities => _favoriteActivityIds,
        DetailCategory.culture => _favoriteCultureIds,
        DetailCategory.food => _favoriteFoodIds,
        DetailCategory.localProducts => _favoriteLocalProductIds,
      };
      if (isFavorite) {
        targetSet.add(item.id);
      } else {
        targetSet.remove(item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final items = _results.byCategory(_selectedFilter);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(45),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vietnam',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
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
                  onTap: (i) => setState(() => _selectedFilter = i),
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
                      initialFavorite: _isFavoriteForCurrentFilter(
                        items[index],
                      ),
                      onFavoriteChanged: (value) =>
                          _onFavoriteChanged(items[index], value),
                    ),
                    childCount: items.length,
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
  double get minExtent => 90;
  @override
  double get maxExtent => 90;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: statusBarH > 0 ? statusBarH : 0,
        bottom: 6,
        left: 0,
        right: 0,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
        ),
        itemCount: _filterLabels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                _filterLabels[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) =>
      selectedIndex != oldDelegate.selectedIndex;
}

// ─── Result card with carousel ───────────────────────────────────────

class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.item,
    required this.category,
    required this.initialFavorite,
    required this.onFavoriteChanged,
  });

  final SearchResultItem item;
  final DetailCategory category;
  final bool initialFavorite;
  final ValueChanged<bool> onFavoriteChanged;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  late final PageController _imageController;
  late bool _isFavorite;
  final WishlistRepository _wishlistRepository = WishlistRepository();
  bool _favoriteBusy = false;

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;

    final userId = AuthRepository.instance.user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save wishlist.')),
      );
      return;
    }

    final previous = _isFavorite;
    setState(() {
      _favoriteBusy = true;
      _isFavorite = !_isFavorite;
    });
    widget.onFavoriteChanged(_isFavorite);

    try {
      await _wishlistRepository.toggleFavoriteByRawId(
        type: _favoriteTypeForCategory(widget.category),
        rawItemId: widget.item.id,
        fallbackName: widget.item.name,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isFavorite = previous);
      widget.onFavoriteChanged(previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Wishlist update failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _favoriteBusy = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _isFavorite = widget.initialFavorite;
  }

  @override
  void didUpdateWidget(covariant _ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_favoriteBusy && oldWidget.initialFavorite != widget.initialFavorite) {
      _isFavorite = widget.initialFavorite;
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
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.82),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.62),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite
                                ? const Color(0xFFFF4D79)
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                        ),
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
              widget.item.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
