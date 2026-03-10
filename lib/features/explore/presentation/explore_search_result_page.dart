import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../data/explore_search_results_data.dart';

const List<String> _filterLabels = ['ACTIVITIES', 'CULTURE', 'FOOD', 'LOCAL PRODUCTS'];

class ExploreSearchResultPage extends StatefulWidget {
  final String destination;

  const ExploreSearchResultPage({super.key, required this.destination});

  @override
  State<ExploreSearchResultPage> createState() =>
      _ExploreSearchResultPageState();
}

class _ExploreSearchResultPageState extends State<ExploreSearchResultPage> {
  int _selectedFilter = 0;
  late final DestinationResults _results;

  @override
  void initState() {
    super.initState();
    _results = getResultsForDestination(widget.destination);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final items = _results.byCategory(_selectedFilter);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Top bar: back + search ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12, statusBarH + 8, AppConstants.pagePadding, 4,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
                          Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _results.destination,
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
                ],
              ),
            ),
          ),

          // ── Title: "Discover [City]!" ──────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding, 10, AppConstants.pagePadding, 8,
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(text: 'Discover '),
                    TextSpan(
                      text: '${_results.destination}!',
                      style: const TextStyle(color: AppColors.primary),
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
              AppConstants.pagePadding, 10, AppConstants.pagePadding, 24,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ResultCard(item: items[index]),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sticky filter delegate ──────────────────────────────────────────

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  _StickyFilterDelegate({required this.selectedIndex, required this.onTap});

  @override
  double get minExtent => 90;
  @override
  double get maxExtent => 90;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: statusBarH > 0 ? statusBarH : 0, bottom: 6, left: 0, right: 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
  const _ResultCard({required this.item});
  final SearchResultItem item;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.item.images.length;

    return GestureDetector(
      onTap: () {
        context.push(AppRoutes.exploreDetail, extra: {'id': widget.item.id, 'name': widget.item.name});
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
                    itemCount: imageCount,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      return Container(
                        color: Colors.grey.shade300,
                        child: Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                      );
                    },
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Icon(
                      widget.item.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: widget.item.isFavorite ? AppColors.primary : Colors.white,
                      size: 24,
                    ),
                  ),
                  if (imageCount > 1)
                    Positioned(
                      bottom: 10, left: 12,
                      child: Row(
                        children: List.generate(imageCount, (i) {
                          return Container(
                            width: i == _currentPage ? 18 : 6, height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i == _currentPage ? Colors.white : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  Positioned(
                    bottom: 10, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            widget.item.rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      ),
    );
  }
}
