import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/explore/presentation/explore_category_page.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

import '../data/recommend_repository.dart';

class CityDestinationsSection extends StatefulWidget {
  const CityDestinationsSection({super.key, required this.idProvince});

  final String idProvince;

  @override
  State<CityDestinationsSection> createState() =>
      _CityDestinationsSectionState();
}

class _CityDestinationsSectionState extends State<CityDestinationsSection> {
  late final Future<ProvinceDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = RecommendRepository().getTopPlacesForProvince(widget.idProvince);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProvinceDetail>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<ProvinceDetail> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final List<ProvinceTopPlace> places =
            snapshot.data?.topPlaces ?? const <ProvinceTopPlace>[];
        if (snapshot.hasError || places.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Destinations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final ProvinceTopPlace place in places)
              ExploreResultCard(
                item: ExploreItem(
                  id: place.idPlace,
                  name: place.name,
                  imagePath: place.coverImage?.trim().isNotEmpty == true
                      ? place.coverImage!.trim()
                      : place.galleryUrl?.trim() ?? '',
                  subtitle: place.subcategoryName ?? place.address,
                  provinceId: widget.idProvince,
                  category: DetailCategory.activities,
                ),
                category: DetailCategory.activities,
                favoriteType: FavoriteType.place,
                rating: place.averageRating,
                trackExploreBehavior: false,
                onTap: () => context.push(
                  AppRoutes.recommendedPlaceDetailPath(
                    idProvince: widget.idProvince,
                    idPlace: place.idPlace,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
