import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/recommend_destination.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/dest_section_title.dart';

/// Recommendation 1.4 — destination detail for the **Where** flow.
///
/// Shows "Discover, {name}!" title, a pill tab bar (ALL / BEST TIME /
/// ACTIVITIES / FOOD / TIPS), and filtered content sections below.
/// Tabs are view-filters of the same data — not independent data sets.
class RecommendWhereDetailPage extends StatefulWidget {
  const RecommendWhereDetailPage({super.key, required this.destination});

  final RecommendDestination destination;

  @override
  State<RecommendWhereDetailPage> createState() =>
      _RecommendWhereDetailPageState();
}

enum _Tab { all, bestTime, activities, food, tips }

class _RecommendWhereDetailPageState extends State<RecommendWhereDetailPage> {
  _Tab _activeTab = _Tab.all;
  bool _isFavorite = false;

  RecommendDestination get dest => widget.destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Hero image ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    dest.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                      child: const Icon(
                        Icons.landscape_rounded,
                        size: 72,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Bottom gradient so the pinned bar blends smoothly
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleIconButton(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                  iconColor: _isFavorite ? Colors.redAccent : Colors.white,
                  onTap: () => setState(() => _isFavorite = !_isFavorite),
                ),
              ),
            ],
          ),

          // ── Title + tab bar ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                20,
                AppConstants.pagePadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Discover, {name}!" — black + primary blue split
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        const TextSpan(text: 'Discover, '),
                        TextSpan(
                          text: '${dest.name}!',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pill tab bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _Tab.values.map((tab) {
                        final active = tab == _activeTab;
                        return GestureDetector(
                          onTap: () => setState(() => _activeTab = tab),
                          child: AnimatedContainer(
                            duration: AppConstants.defaultAnimation,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              _tabLabel(tab),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Tab content ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              0,
              AppConstants.pagePadding,
              40,
            ),
            sliver: SliverToBoxAdapter(child: _buildTabContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case _Tab.all:
        return _AllContent(dest: dest);
      case _Tab.bestTime:
        return dest.bestTimeTitle.isEmpty
            ? const _NoData()
            : _BestTimeContent(dest: dest);
      case _Tab.activities:
        return dest.activities.isEmpty
            ? const _NoData()
            : _ActivitiesContent(dest: dest);
      case _Tab.food:
        return dest.cuisine.isEmpty
            ? const _NoData()
            : _FoodContent(dest: dest);
      case _Tab.tips:
        return dest.tips.isEmpty ? const _NoData() : _TipsContent(dest: dest);
    }
  }

  String _tabLabel(_Tab tab) {
    switch (tab) {
      case _Tab.all:
        return 'ALL';
      case _Tab.bestTime:
        return 'BEST TIME';
      case _Tab.activities:
        return 'ACTIVITIES';
      case _Tab.food:
        return 'FOOD';
      case _Tab.tips:
        return 'TIPS';
    }
  }
}

// ── Tab content widgets ──────────────────────────────────────────────

class _AllContent extends StatelessWidget {
  const _AllContent({required this.dest});

  final RecommendDestination dest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dest.description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.65,
            color: AppColors.textPrimary,
          ),
        ),
        if (dest.bestTimeTitle.isNotEmpty) ...[
          const SizedBox(height: 28),
          _BestTimeContent(dest: dest),
        ],
        if (dest.activities.isNotEmpty) ...[
          const SizedBox(height: 28),
          _ActivitiesContent(dest: dest),
        ],
        if (dest.cuisine.isNotEmpty) ...[
          const SizedBox(height: 28),
          _FoodContent(dest: dest),
        ],
        if (dest.tips.isNotEmpty) ...[
          const SizedBox(height: 28),
          _TipsContent(dest: dest),
        ],
      ],
    );
  }
}

class _BestTimeContent extends StatelessWidget {
  const _BestTimeContent({required this.dest});

  final RecommendDestination dest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DestSectionTitle('Best month to visit'),
        const SizedBox(height: 8),
        Text(
          dest.bestTimeTitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        ...dest.bestTimeDetails.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                Expanded(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivitiesContent extends StatelessWidget {
  const _ActivitiesContent({required this.dest});

  final RecommendDestination dest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DestSectionTitle('Activities'),
        const SizedBox(height: 12),
        ...dest.activities.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    a,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodContent extends StatelessWidget {
  const _FoodContent({required this.dest});

  final RecommendDestination dest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DestSectionTitle('Must-try Cuisine'),
        const SizedBox(height: 14),
        ...dest.cuisine.asMap().entries.map((e) {
          final index = e.key + 1;
          final food = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index.  ${food.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                  child: Image.network(
                    food.imagePath,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 180,
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TipsContent extends StatelessWidget {
  const _TipsContent({required this.dest});

  final RecommendDestination dest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DestSectionTitle('Tips'),
        const SizedBox(height: 10),
        ...dest.tips.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          'No information available',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
