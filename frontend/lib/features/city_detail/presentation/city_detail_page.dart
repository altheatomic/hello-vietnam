import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/city_detail/data/city_detail_mock_data.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

class CityDetailPage extends StatelessWidget {
  const CityDetailPage({super.key, required this.request});

  final CityDetailRequest request;

  @override
  Widget build(BuildContext context) {
    final cityDetail = resolveCityDetail(request);

    return SharedItemDetailPage(
      detail: cityDetail.detail,
      favoriteType: FavoriteType.city,
      favoriteRawId: request.id,
      favoriteName: request.name,
      insertedSectionsBuilder: (context, detail) => <Widget>[
        _CitySectionTitle(title: context.l10n.ui('Best time to visit')),
        const SizedBox(height: 12),
        _BestTimeCard(
          title: cityDetail.bestTimeTitle,
          details: cityDetail.bestTimeDetails,
        ),
      ],
    );
  }
}

class _CitySectionTitle extends StatelessWidget {
  const _CitySectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark
            ? Theme.of(context).colorScheme.onSurface
            : AppColors.textPrimary,
      ),
    );
  }
}

class _BestTimeCard extends StatelessWidget {
  const _BestTimeCard({required this.title, required this.details});

  final String title;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primaryLight.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Recommended season',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      detail,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
