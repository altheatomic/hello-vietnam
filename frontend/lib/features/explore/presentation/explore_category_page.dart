import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/data/explore_tracking_service.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/profile/data/wishlist_controller.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

import 'widgets/explore_floating_back_button.dart';
import 'widgets/explore_preview_widgets.dart';

const List<String> _filterLabels = <String>[
  'ACTIVITIES',
  'CULTURE',
  'FOOD',
  'LOCAL PRODUCTS',
];

class ExploreCategoryPage extends StatefulWidget {
  const ExploreCategoryPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ExploreCategoryPage> createState() => _ExploreCategoryPageState();
}

class _ExploreCategoryPageState extends State<ExploreCategoryPage> {
  static const int _pageSize = 2;

  final ExploreRepository _repository = ExploreRepository.instance;

  late int _selectedFilter;
  late final ScrollController _scrollController;
  int _visibleItemCount = _pageSize;

  bool _isLoading = true;
  String? _errorMessage;
  List<_CategoryResults> _categories = const <_CategoryResults>[];

  @override
  void initState() {
    super.initState();
    final int maxIndex = _filterLabels.length - 1;
    if (widget.initialTab < 0) {
      _selectedFilter = 0;
    } else if (widget.initialTab > maxIndex) {
      _selectedFilter = maxIndex;
    } else {
      _selectedFilter = widget.initialTab;
    }
    _scrollController = ScrollController()..addListener(_handleScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<List<ExploreItem>> results =
          await Future.wait(<Future<List<ExploreItem>>>[
            _repository.loadCategoryItems(DetailCategory.activities),
            _repository.loadCategoryItems(DetailCategory.culture),
            _repository.loadCategoryItems(DetailCategory.food),
            _repository.loadCategoryItems(DetailCategory.localProducts),
          ]);

      if (!mounted) return;

      setState(() {
        _categories = <_CategoryResults>[
          _CategoryResults(
            category: DetailCategory.activities,
            items: results[0],
            emptyMessage: _repository.descriptionForCategory(
              DetailCategory.activities,
            ),
          ),
          _CategoryResults(
            category: DetailCategory.culture,
            items: results[1],
            emptyMessage: _repository.descriptionForCategory(
              DetailCategory.culture,
            ),
          ),
          _CategoryResults(
            category: DetailCategory.food,
            items: results[2],
            emptyMessage: _repository.descriptionForCategory(
              DetailCategory.food,
            ),
          ),
          _CategoryResults(
            category: DetailCategory.localProducts,
            items: results[3],
            emptyMessage: _repository.descriptionForCategory(
              DetailCategory.localProducts,
            ),
          ),
        ];
        _isLoading = false;
        _resetPagination();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categories = const <_CategoryResults>[];
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 280) return;
    _loadMore();
  }

  void _loadMore() {
    if (_categories.isEmpty) return;
    final int total = _categories[_selectedFilter].items.length;
    if (_visibleItemCount >= total) return;

    setState(() {
      final int nextCount = _visibleItemCount + _pageSize;
      _visibleItemCount = nextCount > total ? total : nextCount;
    });
  }

  void _resetPagination() {
    if (_categories.isEmpty) {
      _visibleItemCount = _pageSize;
      return;
    }

    final int total = _categories[_selectedFilter].items.length;
    _visibleItemCount = total < _pageSize ? total : _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (_categories.isEmpty)
            _PageStateMessage(
              title: 'Unable to load Explore right now.',
              subtitle: _errorMessage,
              actionLabel: 'Retry',
              onTap: _load,
            )
          else
            _buildLoadedState(context, statusBarH),
          ExploreFloatingBackButton(onTap: () => context.pop()),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, double statusBarH) {
    final _CategoryResults currentCategory = _categories[_selectedFilter];
    final List<ExploreItem> items = currentCategory.items;
    final int visibleCount = items.length < _visibleItemCount
        ? items.length
        : _visibleItemCount;
    final bool hasMore = visibleCount < items.length;

    return CustomScrollView(
      controller: _scrollController,
      slivers: <Widget>[
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
                children: <Widget>[
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
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyFilterDelegate(
            selectedIndex: _selectedFilter,
            onTap: (int index) {
              setState(() {
                _selectedFilter = index;
                _resetPagination();
              });
            },
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _PageStateMessage(
              title:
                  'No ${_filterLabels[_selectedFilter].toLowerCase()} found.',
              subtitle: currentCategory.emptyMessage,
            ),
          )
        else ...<Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              10,
              AppConstants.pagePadding,
              24,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _ResultCard(
                  item: items[index],
                  category: currentCategory.category,
                ),
                childCount: visibleCount,
              ),
            ),
          ),
          if (hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ],
    );
  }
}

class _CategoryResults {
  const _CategoryResults({
    required this.category,
    required this.items,
    this.emptyMessage,
  });

  final DetailCategory category;
  final List<ExploreItem> items;
  final String? emptyMessage;
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  _StickyFilterDelegate({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

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
    final double statusBarH = MediaQuery.of(context).padding.top;
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
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool isSelected = index == selectedIndex;
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
                context.l10n.ui(_filterLabels[index]),
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
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) {
    return selectedIndex != oldDelegate.selectedIndex;
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.item, required this.category});

  final ExploreItem item;
  final DetailCategory category;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  late final PageController _imageController;
  final WishlistController _wishlistController = WishlistController.instance;
  final ExploreTrackingService _trackingService =
      ExploreTrackingService.instance;

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
      if (!mounted) return;
      if (result != null) {
        unawaited(
          _trackingService.trackFavoriteChanged(
            category: widget.category,
            contentId: widget.item.id,
            provinceId: widget.item.provinceId,
            isFavorite: result,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.ui('Please sign in to update wishlist.')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.ui('Update wishlist failed')}: $error'),
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

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const List<String> emptyImages = <String>[];
    final List<String> itemImages = widget.item.imagePath.trim().isEmpty
        ? emptyImages
        : <String>[widget.item.imagePath];
    final int imageCount = itemImages.length;

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.detailPathForCategory(widget.category),
          extra: ItemDetailRequest(
            id: widget.item.id,
            name: widget.item.name,
            category: widget.category,
            fallbackImages: itemImages,
            fallbackImagePath: imageCount == 0 ? null : itemImages.first,
            trackExploreBehavior: true,
            exploreProvinceId: widget.item.provinceId,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (imageCount == 0)
                      Container(color: const Color(0xFFD8F2FD))
                    else
                      PageView.builder(
                        controller: _imageController,
                        physics: const BouncingScrollPhysics(
                          parent: PageScrollPhysics(),
                        ),
                        itemCount: imageCount,
                        itemBuilder: (BuildContext context, int index) {
                          return AnimatedBuilder(
                            animation: _imageController,
                            builder: (BuildContext context, Widget? child) {
                              final double page = _imageController.hasClients
                                  ? (_imageController.page ??
                                        _imageController.initialPage.toDouble())
                                  : _imageController.initialPage.toDouble();
                              final double distance = (page - index)
                                  .abs()
                                  .clamp(0.0, 1.0);
                              final double emphasis = (1 - distance).clamp(
                                0.0,
                                1.0,
                              );

                              return Transform.scale(
                                scale: 0.94 + (emphasis * 0.06),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    boxShadow: <BoxShadow>[
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
                              imagePath: itemImages[index],
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
                          children: const <Widget>[
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            SizedBox(width: 3),
                            Text(
                              '4.7',
                              style: TextStyle(
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

class _PageStateMessage extends StatelessWidget {
  const _PageStateMessage({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.ui(title),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            if (actionLabel != null && onTap != null) ...<Widget>[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onTap,
                child: Text(context.l10n.ui(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
