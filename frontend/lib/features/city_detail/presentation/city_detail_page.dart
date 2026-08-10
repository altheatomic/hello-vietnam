import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/city_detail/data/city_detail_mock_data.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import 'package:hellovietnam/features/recommend/presentation/city_destinations_section.dart';
import 'package:hellovietnam/core/utils/vietnamese_text_utils.dart';

class CityDetailPage extends StatelessWidget {
  const CityDetailPage({super.key, required this.request});

  final CityDetailRequest request;

  @override
  Widget build(BuildContext context) {
    final cityDetail = resolveCityDetail(request);

    return SharedItemDetailPage(
      detail: cityDetail.detail.copyWith(
        name: removeVietnameseDiacritics(cityDetail.detail.name),
      ),
      favoriteType: FavoriteType.city,
      favoriteRawId: request.id,
      favoriteName: request.name,
      showReviews: false,
      showWhatToExpect: false,
      showTrailingGallery: false,
      showFeedbackAction: false,
      showRatingBadge: false,
      insertedSectionsBuilder: (context, detail) => <Widget>[
        if (request.id.trim().isNotEmpty) ...<Widget>[
          _CityDetailActionRow(request: request),
          const SizedBox(height: 28),
        ],
        CityDestinationsSection(idProvince: request.id),
      ],
    );
  }
}

/// "Create Trip Plan" + "Explore this province" actions for the selected
/// province. Only rendered when [CityDetailRequest.id] resolves to a real
/// province id (see the empty-string guard in [CityDetailPage.build]).
class _CityDetailActionRow extends StatelessWidget {
  const _CityDetailActionRow({required this.request});

  final CityDetailRequest request;

  void _onCreateTripPlan(BuildContext context) {
    context.push(
      AppRoutes.tripPlannerDuration,
      extra: TripWizardData(
        idProvince: request.id,
        provinceName: request.name,
      ).toJson(),
    );
  }

  void _onExploreProvince(BuildContext context) {
    context.push(
      AppRoutes.exploreSearchResult,
      extra: ExploreProvince(id: request.id, name: request.name).toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.pagePadding,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _onCreateTripPlan(context),
              icon: const Icon(Icons.route_rounded, size: 20),
              label: Text(context.l10n.ui('Create Trip Plan')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _onExploreProvince(context),
              icon: const Icon(Icons.explore_outlined, size: 20),
              label: Text(context.l10n.ui('Explore this province')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
