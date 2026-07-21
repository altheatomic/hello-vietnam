import 'package:flutter/material.dart';
import 'package:hellovietnam/features/city_detail/data/city_detail_mock_data.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
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
      insertedSectionsBuilder: (context, detail) => <Widget>[
        CityDestinationsSection(idProvince: request.id),
      ],
    );
  }
}
