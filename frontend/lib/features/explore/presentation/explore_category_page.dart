import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
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
    final List<SearchResultItem> items = _results.byCategory(_selectedFilter);
    final int visibleCount = items.length < _visibleItemCount
        ? items.length
        : _visibleItemCount;
    final bool hasMore = visibleCount < items.length;

    return Scaffold(
      backgroundColor: Colors.white,
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
  const _ResultCard({required this.item, required this.category});

  final SearchResultItem item;
  final DetailCategory category;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  late final PageController _imageController;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
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
                      child: Icon(
                        widget.item.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: widget.item.isFavorite
                            ? AppColors.primary
                            : Colors.white,
                        size: 24,
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
