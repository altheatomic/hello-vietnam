import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

class CityDetailRequest {
  const CityDetailRequest({
    required this.id,
    required this.name,
    this.fallbackImages = const <String>[],
    this.fallbackImagePath,
    this.fallbackRating,
    this.description,
  });

  final String id;
  final String name;
  final List<String> fallbackImages;
  final String? fallbackImagePath;
  final double? fallbackRating;

  /// Real translated description (e.g. description_en) from the backend,
  /// when the caller already resolved a matching [RecommendDestination].
  final String? description;
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
