import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/app_scaffold.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../../data/recommend_mock_data.dart';
import '../../domain/recommend_destination.dart';

/// Recommendation 2.3 — list of destinations filtered by the chosen
/// travel date range (matching on [RecommendDestination.bestMonths]).
class RecommendWhenResultsPage extends StatelessWidget {
  const RecommendWhenResultsPage({super.key, required this.dateRange});

  final DateTimeRange dateRange;

  List<RecommendDestination> get _filtered {
    final month = dateRange.start.month;
    return mockRecommendDestinations
        .where((d) => d.bestMonths.isEmpty || d.bestMonths.contains(month))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return AppScaffold(
      title: 'Best for You',
      showBack: true,
      body: results.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_today_rounded,
              message:
                  'No destinations found for your travel dates.\nTry a different period.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                20,
                AppConstants.pagePadding,
                32,
              ),
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 20),
              itemBuilder: (context, i) => _WhenDestCard(
                destination: results[i],
                onTap: () => context.push(
                  AppRoutes.recommendWhenDetail,
                  extra: results[i],
                ),
              ),
            ),
    );
  }
}

// ── Vertical destination card (When flow) ────────────────────────────

class _WhenDestCard extends StatefulWidget {
  const _WhenDestCard({required this.destination, required this.onTap});

  final RecommendDestination destination;
  final VoidCallback onTap;

  @override
  State<_WhenDestCard> createState() => _WhenDestCardState();
}

class _WhenDestCardState extends State<_WhenDestCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image with favourite overlay ──────────────────
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.cardRadius),
                child: Image.network(
                  dest.imagePath,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.25),
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.landscape_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              // Favourite heart — matches RecommendationCard treatment
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _isFavorite = !_isFavorite),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 18,
                      color: _isFavorite
                          ? Colors.redAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Name + star rating ────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  dest.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.starColor,
              ),
              const SizedBox(width: 3),
              Text(
                dest.rating.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ── Tag line ──────────────────────────────────────
          Text(
            dest.tags.join(' • '),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),

          const SizedBox(height: 4),

          // ── Short description ─────────────────────────────
          Text(
            dest.shortDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
