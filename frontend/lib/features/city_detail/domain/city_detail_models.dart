import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

class CityDetailRequest {
  const CityDetailRequest({
    required this.id,
    required this.name,
    this.idProvince,
    this.fallbackImages = const <String>[],
    this.fallbackImagePath,
    this.fallbackRating,
  });

  final String id;
  final String name;

  /// UUID of the province in the DB. When set, city_detail_page fetches
  /// real place data from /api/recommend/province/{idProvince}.
  final String? idProvince;

  final List<String> fallbackImages;
  final String? fallbackImagePath;
  final double? fallbackRating;
}

class CityDetailData {
  const CityDetailData({
    required this.detail,
    required this.bestTimeTitle,
    required this.bestTimeDetails,
  });

  final ItemDetail detail;
  final String bestTimeTitle;
  final List<String> bestTimeDetails;
}
