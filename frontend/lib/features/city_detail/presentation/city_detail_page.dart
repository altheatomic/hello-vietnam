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
///
/// StatefulWidget (not Stateless) specifically to hold [_isNavigating]:
/// double-tapping either button used to race 2 near-simultaneous
/// context.push() calls against the same stale currentConfiguration,
/// duplicating the parent shell route's page key
/// (Navigator._debugCheckDuplicatedPageKeys()) — asserting on web debug,
/// and leaving the Element tree unable to reconcile on Android release/
/// profile builds (where asserts are stripped), observed as an ANR. Both
/// buttons are guarded and disabled together while either navigation is
/// in flight, since both leave this page.
class _CityDetailActionRow extends StatefulWidget {
  const _CityDetailActionRow({required this.request});

  final CityDetailRequest request;

  @override
  State<_CityDetailActionRow> createState() => _CityDetailActionRowState();
}

class _CityDetailActionRowState extends State<_CityDetailActionRow> {
  bool _isNavigating = false;
  // Which button triggered the in-flight navigation, so only that one shows
  // a spinner while both are disabled — 'trip' | 'explore' | null.
  String? _pendingAction;

  Future<void> _onCreateTripPlan(BuildContext context) async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _pendingAction = 'trip';
    });
    try {
      await context.push(
        AppRoutes.tripPlannerDuration,
        extra: TripWizardData(
          idProvince: widget.request.id,
          provinceName: widget.request.name,
        ).toJson(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _pendingAction = null;
        });
      }
    }
  }

  Future<void> _onExploreProvince(BuildContext context) async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _pendingAction = 'explore';
    });
    try {
      await context.push(
        AppRoutes.exploreSearchResult,
        extra: ExploreProvince(
          id: widget.request.id,
          name: widget.request.name,
        ).toJson(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _pendingAction = null;
        });
      }
    }
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
              onPressed: _isNavigating
                  ? null
                  : () => _onCreateTripPlan(context),
              icon: _pendingAction == 'trip'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.route_rounded, size: 20),
              label: Text(context.l10n.ui('Create Trip Plan')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.6,
                ),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
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
              onPressed: _isNavigating
                  ? null
                  : () => _onExploreProvince(context),
              icon: _pendingAction == 'explore'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.explore_outlined, size: 20),
              label: Text(context.l10n.ui('Explore this province')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.primary.withValues(
                  alpha: 0.5,
                ),
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
