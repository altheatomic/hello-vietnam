import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';

import '../domain/recommend_destination.dart';

class ProvinceTopPlace {
  const ProvinceTopPlace({
    required this.idPlace,
    required this.name,
    this.address,
    this.coverImage,
    this.galleryUrl,
    this.averageRating,
    this.reviewCount,
    this.subcategoryName,
    this.tagMatch = 0,
  });

  final String idPlace;
  final String name;
  final String? address;
  final String? coverImage;
  final String? galleryUrl;
  final double? averageRating;
  final int? reviewCount;
  final String? subcategoryName;
  final double tagMatch;

  factory ProvinceTopPlace.fromJson(Map<String, dynamic> json) {
    return ProvinceTopPlace(
      idPlace: json['id_place'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      coverImage: json['cover_image'] as String?,
      galleryUrl: json['gallery_url'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt(),
      subcategoryName: json['subcategory_name'] as String?,
      tagMatch: (json['tag_match'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProvinceDetail {
  const ProvinceDetail({
    required this.idProvince,
    required this.name,
    required this.avgRating,
    required this.placeCount,
    required this.topPlaces,
  });

  final String idProvince;
  final String name;
  final double avgRating;
  final int placeCount;
  final List<ProvinceTopPlace> topPlaces;

  factory ProvinceDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPlaces =
        json['top_places'] as List<dynamic>? ?? <dynamic>[];
    return ProvinceDetail(
      idProvince: json['id_province'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      placeCount: (json['place_count'] as num?)?.toInt() ?? 0,
      topPlaces: rawPlaces
          .whereType<Map<String, dynamic>>()
          .map(ProvinceTopPlace.fromJson)
          .toList(),
    );
  }
}

class RecommendRepository {
  RecommendRepository({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient ?? SupabaseFunctionClient();

  final SupabaseFunctionClient _functionClient;

  Future<List<RecommendDestination>> getPersonalizedProvinces({
    int limit = 20,
  }) async {
    final Map<String, dynamic> data = await _invoke(<String, Object?>{
      'action': 'getPersonalizedProvinces',
      'limit': limit,
    });
    final List<dynamic> raw =
        data['provinces'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_destinationFromJson)
        .toList();
  }

  Future<ProvinceDetail> getTopPlacesForProvince(
    String idProvince, {
    int limit = 20,
  }) async {
    final Map<String, dynamic> data = await _invoke(<String, Object?>{
      'action': 'getTopPlacesForProvince',
      'idProvince': idProvince,
      'limit': limit,
    });
    return ProvinceDetail.fromJson(data);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) {
    return _functionClient.invokeJson(
      Env.recommendFunction,
      body: body,
      requireAuth: true,
      timeout: const Duration(seconds: 45),
    );
  }

  RecommendDestination _destinationFromJson(Map<String, dynamic> json) {
    final List<String> gallery =
        (json['gallery'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList();
    final String imagePath =
        json['cover_image'] as String? ??
        (gallery.isNotEmpty ? gallery.first : '');
    final int placeCount = (json['place_count'] as num?)?.toInt() ?? 0;
    final double avgRating =
        (json['avg_rating'] as num?)?.toDouble() ?? 0;

    return RecommendDestination(
      id: json['id_province'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortDescription: '$placeCount places · ★ $avgRating',
      description: json['description'] as String? ?? '',
      imagePath: imagePath,
      // Not populated by backend recommend_provinces() response (which no
      // longer computes ML scores for province listing); defaults to 0.
      // Retained for compatibility with mock data used elsewhere
      // (travel_recommendation_service.dart).
      rating: (json['final_score'] as num?)?.toDouble() ?? 0,
      avgRating: avgRating,
      gallery: gallery,
      bestMonths: const <int>[],
    );
  }
}
