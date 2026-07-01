import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/city_detail/data/city_detail_mock_data.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/recommend/data/recommend_repository.dart';

class CityDetailPage extends StatefulWidget {
  const CityDetailPage({super.key, required this.request});

  final CityDetailRequest request;

  @override
  State<CityDetailPage> createState() => _CityDetailPageState();
}

class _CityDetailPageState extends State<CityDetailPage> {
  CityDetailData? _cityDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idProvince = widget.request.idProvince;
    if (idProvince != null) {
      try {
        final detail = await RecommendRepository().getProvinceDetail(
          idProvince: idProvince,
        );
        if (!mounted) return;
        if (detail.placeCount > 0) {
          setState(() {
            _cityDetail = _buildFromApi(detail);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {
        // fall through to mock
      }
    }
    if (!mounted) return;
    setState(() {
      _cityDetail = resolveCityDetail(widget.request);
      _isLoading = false;
    });
  }

  CityDetailData _buildFromApi(ProvinceDetail detail) {
    // Collect real images from top places (cover + gallery_url)
    final imageUrls = <String>[];
    for (final p in detail.topPlaces) {
      if (p.coverImage != null && p.coverImage!.isNotEmpty) {
        imageUrls.add(p.coverImage!);
      } else if (p.galleryUrl != null && p.galleryUrl!.isNotEmpty) {
        imageUrls.add(p.galleryUrl!);
      }
      if (imageUrls.length >= 6) break;
    }
    // Supplement with request fallbacks if needed
    for (final img in widget.request.fallbackImages) {
      if (img.isNotEmpty && !imageUrls.contains(img)) imageUrls.add(img);
      if (imageUrls.length >= 6) break;
    }

    final topNames = detail.topPlaces
        .take(5)
        .map((p) => p.name)
        .where((n) => n.isNotEmpty)
        .join(' · ');

    final whatToExpect = topNames.isNotEmpty
        ? 'Top picks: $topNames.'
        : '${widget.request.name} offers memorable local culture and scenic highlights.';

    return CityDetailData(
      detail: ItemDetail(
        id:           detail.idProvince,
        name:         widget.request.name,
        category:     DetailCategory.culture,
        images:       imageUrls.isNotEmpty ? imageUrls : const <String>[''],
        rating:       detail.avgRating,
        reviewCount:  detail.placeCount,
        ratingLabel:  _ratingLabel(detail.avgRating),
        description:
            'A top destination in Vietnam with ${detail.placeCount} '
            'places to explore — from local culture to scenic highlights.',
        whatToExpect: whatToExpect,
        reviews:      const <ItemReview>[],
      ),
      bestTimeTitle:   'Best enjoyed year-round',
      bestTimeDetails: <String>[
        'Comfortable weather makes it easier to explore on foot.',
        'Clearer days are best for sightseeing and local food stops.',
        'Plan early-morning or late-afternoon outings for the most pleasant experience.',
      ],
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 4.8) return 'Fantastic';
    if (rating >= 4.5) return 'Amazing';
    if (rating >= 4.2) return 'Great';
    return 'Good';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cityDetail = _cityDetail!;

    return SharedItemDetailPage(
      detail: cityDetail.detail,
      insertedSectionsBuilder: (context, detail) => <Widget>[
        const _CitySectionTitle(title: 'Best time to visit'),
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.32),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textPrimary,
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
