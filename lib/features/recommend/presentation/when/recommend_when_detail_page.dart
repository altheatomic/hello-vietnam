import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/recommend_destination.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/dest_section_title.dart';

/// Recommendation 2.4 — destination detail for the **When** flow.
///
/// Layout (top-to-bottom):
///   • Full-bleed hero image with back + favourite overlays
///   • Name + gold rating chip + tag chips
///   • Description
///   • Images gallery (horizontal scroll) with "See all"
///   • "The highlights of a visit" section
///   • Map placeholder
class RecommendWhenDetailPage extends StatefulWidget {
  const RecommendWhenDetailPage({super.key, required this.destination});

  final RecommendDestination destination;

  @override
  State<RecommendWhenDetailPage> createState() =>
      _RecommendWhenDetailPageState();
}

class _RecommendWhenDetailPageState
    extends State<RecommendWhenDetailPage> {
  bool _isFavorite = false;

  RecommendDestination get dest => widget.destination;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Full-bleed hero ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: false,
            snap: false,
            floating: false,
            backgroundColor: Colors.transparent,
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
                  // Dark gradient at top so buttons stay visible
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 110,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.38),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Back button
                  Positioned(
                    top: topPadding + 8,
                    left: 12,
                    child: CircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  // Favourite button
                  Positioned(
                    top: topPadding + 8,
                    right: 12,
                    child: CircleIconButton(
                      icon: _isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: _isFavorite
                          ? Colors.redAccent
                          : Colors.white,
                      onTap: () =>
                          setState(() => _isFavorite = !_isFavorite),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── White body ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + rating chip row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          dest.name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Gold rating chip — matches RecommendationCard star style
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dest.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Tag chips
                  if (dest.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: dest.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Description
                  Text(
                    dest.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Image gallery ───────────────────────────────────────
          if (dest.gallery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  0,
                  AppConstants.pagePadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const DestSectionTitle('Images'),
                        Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dest.gallery.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            dest.gallery[i],
                            width: 120,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 120,
                              color: AppColors.primaryLight
                                  .withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.image_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Highlights ──────────────────────────────────────────
          if (dest.highlights.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  24,
                  AppConstants.pagePadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DestSectionTitle('The highlights of a visit'),
                    const SizedBox(height: 10),
                    Text(
                      dest.highlights,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Map placeholder ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                24,
                AppConstants.pagePadding,
                40,
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.cardRadius),
                child: Container(
                  height: 180,
                  color: AppColors.primaryLight.withValues(alpha: 0.12),
                  child: Stack(
                    children: [
                      // Grid lines to suggest a map surface
                      CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _GridPainter(),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 40,
                              color: AppColors.primary
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dest.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
