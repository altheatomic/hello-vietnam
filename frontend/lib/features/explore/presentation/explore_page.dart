import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/personalization/data/travel_preferences_repository.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';

import 'widgets/explore_floating_back_button.dart';
import 'widgets/explore_preview_widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.repository});

  final ExploreRepository? repository;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _selectedFilter = 0;
  late final PageController _featuredController;
  late final ScrollController _scrollController;
  ExploreSectionsData? _sectionsData;
  Object? _loadError;
  bool _isLoading = true;
  bool _isScrollingToSection = false;
  bool _isScrollSyncScheduled = false;
  int _sectionCount = 0;

  final List<GlobalKey> _sectionKeys = List<GlobalKey>.generate(
    4,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    _featuredController = PageController(viewportFraction: 0.42);
    _scrollController = ScrollController()..addListener(_scheduleTabSync);
    unawaited(_loadInitialSections());
  }

  @override
  void dispose() {
    _featuredController.dispose();
    _scrollController
      ..removeListener(_scheduleTabSync)
      ..dispose();
    super.dispose();
  }

  Future<void> _scrollToSection(int index) async {
    setState(() => _selectedFilter = index);
    final BuildContext? keyContext = _sectionKeys[index].currentContext;
    if (keyContext == null) return;

    _isScrollingToSection = true;
    await Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _isScrollingToSection = false;
    _scheduleTabSync();
  }

  void _scheduleTabSync() {
    if (_isScrollSyncScheduled) return;
    _isScrollSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScrollSyncScheduled = false;
      _syncTabWithScroll();
    });
  }

  void _syncTabWithScroll() {
    if (!mounted || _isScrollingToSection || !_scrollController.hasClients) {
      return;
    }

    final int sectionCount = _sectionCount;
    if (sectionCount == 0) return;

    int visibleIndex = 0;
    final double activationLine = _StickyFilterDelegate.extent + 12;

    for (int index = 0; index < sectionCount; index++) {
      final BuildContext? sectionContext = _sectionKeys[index].currentContext;
      final RenderObject? renderObject = sectionContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;

      final double sectionTop = renderObject.localToGlobal(Offset.zero).dy;
      if (sectionTop <= activationLine) {
        visibleIndex = index;
      } else {
        break;
      }
    }

    if (_scrollController.position.extentAfter <= 1) {
      visibleIndex = sectionCount - 1;
    }

    if (visibleIndex == _selectedFilter) return;
    setState(() => _selectedFilter = visibleIndex);
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.go(AppRoutes.home);
  }

  void _retry() {
    unawaited(_loadFreshSections(showLoading: true));
  }

  Future<void> _loadInitialSections() async {
    final ExploreSectionsData? cached = await _repository.loadCachedSections();
    if (!mounted) return;

    if (cached != null) {
      setState(() {
        _sectionsData = cached;
        _loadError = null;
        _isLoading = false;
      });
      unawaited(_loadFreshSections(showLoading: false));
      return;
    }

    await _loadFreshSections(showLoading: true);
  }

  Future<void> _loadFreshSections({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final ExploreSectionsData fresh = await _repository.loadSections();
      if (!mounted) return;
      setState(() {
        _sectionsData = fresh;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_sectionsData != null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.l10n;
    final double statusBarH = MediaQuery.of(context).padding.top;
    final UserTravelPreferences? preferences =
        TravelPreferencesRepository.instance.currentPreferences;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          Builder(
            builder: (BuildContext context) {
              final List<ExploreCategory> orderedCategories =
                  _orderedCategories(
                    _sectionsData?.categories ?? const <ExploreCategory>[],
                    preferences,
                  );
              final List<_FeaturedProvinceSuggestion> featuredProvinces =
                  _featuredProvincesFromCategories(orderedCategories);
              _sectionCount = orderedCategories.length;

              return CustomScrollView(
                controller: _scrollController,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.15,
                            child: Image.asset(
                              AppConstants.exploreHeaderBgAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: AppColors.primaryLight.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppConstants.pagePadding,
                            statusBarH + 56,
                            AppConstants.pagePadding,
                            16,
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                context.l10n.ui(
                                  'Discover Vietnamese Culture and\nLocal Specialties',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 16),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (_isLoading && _sectionsData == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_loadError != null && _sectionsData == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ExploreStateMessage(
                        message: 'Unable to load Explore right now.',
                        actionLabel: 'Retry',
                        onTap: _retry,
                      ),
                    )
                  else ...<Widget>[
                    if (featuredProvinces.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppConstants.pagePadding,
                                0,
                                AppConstants.pagePadding,
                                10,
                              ),
                              child: Text(
                                context.l10n.ui('Explore by city'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 164,
                              child: PageView.builder(
                                controller: _featuredController,
                                physics: const BouncingScrollPhysics(
                                  parent: PageScrollPhysics(),
                                ),
                                itemCount: featuredProvinces.length,
                                itemBuilder: (context, index) {
                                  final _FeaturedProvinceSuggestion province =
                                      featuredProvinces[index];
                                  return AnimatedBuilder(
                                    animation: _featuredController,
                                    builder: (context, child) {
                                      final double page =
                                          _featuredController.hasClients
                                          ? (_featuredController.page ??
                                                _featuredController.initialPage
                                                    .toDouble())
                                          : _featuredController.initialPage
                                                .toDouble();
                                      final double distance = (page - index)
                                          .abs()
                                          .clamp(0.0, 1.0);
                                      final double emphasis = (1 - distance)
                                          .clamp(0.0, 1.0);

                                      return Transform.scale(
                                        scale: 0.9 + (emphasis * 0.1),
                                        alignment: Alignment.center,
                                        child: Transform.translate(
                                          offset: Offset(
                                            0,
                                            10 - (emphasis * 10),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: index == 0
                                                  ? AppConstants.pagePadding
                                                  : 6,
                                              right:
                                                  index ==
                                                      featuredProvinces.length -
                                                          1
                                                  ? AppConstants.pagePadding
                                                  : 6,
                                            ),
                                            child: _FeaturedProvinceCard(
                                              province: province,
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
                          ],
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (orderedCategories.isNotEmpty)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyFilterDelegate(
                          categories: orderedCategories,
                          selectedIndex: _selectedFilter.clamp(
                            0,
                            orderedCategories.length - 1,
                          ),
                          onTap: (int index) {
                            unawaited(_scrollToSection(index));
                          },
                        ),
                      ),
                    ...List<Widget>.generate(orderedCategories.length, (int i) {
                      final ExploreCategory category = orderedCategories[i];
                      return SliverToBoxAdapter(
                        child: _CategorySection(
                          key: _sectionKeys[i],
                          category: category,
                          categoryIndex: _tabIndexForCategory(category.id),
                        ),
                      );
                    }),
                    if (orderedCategories.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ExploreStateMessage(
                          message: 'Explore content is being updated.',
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ],
              );
            },
          ),
          ExploreFloatingBackButton(onTap: _handleBack),
        ],
      ),
    );
  }

  List<ExploreCategory> _orderedCategories(
    List<ExploreCategory> categories,
    UserTravelPreferences? preferences,
  ) {
    final List<ExploreCategory> ordered = List<ExploreCategory>.from(
      categories,
    );
    if (preferences == null) return ordered;

    ordered.sort((ExploreCategory left, ExploreCategory right) {
      final int leftIndex = _preferredIndex(preferences, left.id);
      final int rightIndex = _preferredIndex(preferences, right.id);
      return leftIndex.compareTo(rightIndex);
    });
    return ordered;
  }

  int _preferredIndex(UserTravelPreferences preferences, String categoryId) {
    final DetailCategory category = _detailCategoryForId(categoryId);
    final int index = preferences.preferredCategories.indexOf(category);
    return index == -1 ? 999 : index;
  }

  List<_FeaturedProvinceSuggestion> _featuredProvincesFromCategories(
    List<ExploreCategory> categories,
  ) {
    final Map<String, _FeaturedProvinceSuggestion> deduped =
        <String, _FeaturedProvinceSuggestion>{};
    for (final ExploreCategory category in categories) {
      for (final ExploreItem item in category.items) {
        final String provinceId = (item.provinceId ?? '').trim();
        final String provinceName = (item.provinceName ?? item.subtitle ?? '')
            .trim();
        if (provinceId.isEmpty || provinceName.isEmpty) {
          continue;
        }
        deduped.putIfAbsent(
          provinceId,
          () => _FeaturedProvinceSuggestion(
            province: ExploreProvince(id: provinceId, name: provinceName),
            imagePath: item.imagePath,
          ),
        );
      }
    }
    return deduped.values.take(6).toList(growable: false);
  }

  int _tabIndexForCategory(String categoryId) {
    switch (categoryId) {
      case 'culture':
        return 1;
      case 'food':
        return 2;
      case 'local_products':
        return 3;
      case 'activities':
      default:
        return 0;
    }
  }

  DetailCategory _detailCategoryForId(String categoryId) {
    switch (categoryId) {
      case 'culture':
        return DetailCategory.culture;
      case 'food':
        return DetailCategory.food;
      case 'local_products':
        return DetailCategory.localProducts;
      case 'activities':
      default:
        return DetailCategory.activities;
    }
  }

  ExploreRepository get _repository =>
      widget.repository ?? ExploreRepository.instance;
}

class _FeaturedProvinceSuggestion {
  const _FeaturedProvinceSuggestion({
    required this.province,
    required this.imagePath,
  });

  final ExploreProvince province;
  final String imagePath;
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  static const double extent = 126;

  final List<ExploreCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  _StickyFilterDelegate({
    required this.categories,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double statusBarH = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: statusBarH + 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
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
                final bool isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
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
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) =>
      selectedIndex != oldDelegate.selectedIndex ||
      categories != oldDelegate.categories;
}

class _FeaturedProvinceCard extends StatelessWidget {
  const _FeaturedProvinceCard({required this.province, this.emphasis = 1});

  final _FeaturedProvinceSuggestion province;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = Color.lerp(
      Colors.white.withValues(alpha: 0.55),
      AppColors.primaryLight.withValues(alpha: 0.95),
      emphasis,
    )!;
    final Color shadowColor = Color.lerp(
      Colors.black.withValues(alpha: 0.05),
      AppColors.primary.withValues(alpha: 0.18),
      emphasis,
    )!;

    return GestureDetector(
      onTap: () {
        context.push(AppRoutes.exploreSearchResult, extra: province.province);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.2 + emphasis),
          boxShadow: <BoxShadow>[
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
            children: <Widget>[
              ExplorePreviewImage(
                imagePath: province.imagePath,
                borderRadius: 22,
              ),
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
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.58),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    context.l10n.ui(province.province.name),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        12,
        AppConstants.pagePadding,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.ui(category.description),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (category.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                category.emptyMessage ??
                    context.l10n.ui('Content is being updated.'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            )
          else
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

class _ExploreItemCard extends StatelessWidget {
  const _ExploreItemCard({required this.item});

  final ExploreItem item;

  @override
  Widget build(BuildContext context) {
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
            trackExploreBehavior: true,
            exploreProvinceId: item.provinceId,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ExplorePreviewImage(imagePath: item.imagePath, borderRadius: 14),
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
                    colors: <Color>[
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

class _ExploreStateMessage extends StatelessWidget {
  const _ExploreStateMessage({
    required this.message,
    this.actionLabel,
    this.onTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            context.l10n.ui(message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (actionLabel != null && onTap != null) ...<Widget>[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onTap,
              child: Text(context.l10n.ui(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}
