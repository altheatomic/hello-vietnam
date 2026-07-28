import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/media/media_url_resolver.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';

import '../domain/recommend_destination.dart';

typedef RecommendMediaResolver = String Function(String rawValue);

class ProvinceTopPlace {
  const ProvinceTopPlace({
    required this.idPlace,
    required this.name,
    this.address,
    this.coverImage,
    this.galleryUrl,
    this.gallery = const <String>[],
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
  final List<String> gallery;
  final double? averageRating;
  final int? reviewCount;
  final String? subcategoryName;
  final double tagMatch;

  factory ProvinceTopPlace.fromJson(
    Map<String, dynamic> json, {
    RecommendMediaResolver mediaResolver = MediaUrlResolver.resolve,
  }) {
    final String coverImage = _resolveOptionalMedia(
      json['cover_image'],
      mediaResolver,
    );
    final String galleryUrl = _resolveOptionalMedia(
      json['gallery_url'],
      mediaResolver,
    );
    final List<String> gallery =
        (json['gallery'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .map(
              (String rawValue) =>
                  _resolveOptionalMedia(rawValue, mediaResolver),
            )
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
    return ProvinceTopPlace(
      idPlace: json['id_place'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      coverImage: coverImage.isEmpty ? null : coverImage,
      galleryUrl: galleryUrl.isNotEmpty
          ? galleryUrl
          : (gallery.isNotEmpty ? gallery.first : null),
      gallery: gallery,
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

  factory ProvinceDetail.fromJson(
    Map<String, dynamic> json, {
    RecommendMediaResolver mediaResolver = MediaUrlResolver.resolve,
  }) {
    final List<Object?> rawPlaces =
        json['top_places'] as List<Object?>? ?? const <Object?>[];
    return ProvinceDetail(
      idProvince: json['id_province'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      placeCount: (json['place_count'] as num?)?.toInt() ?? 0,
      topPlaces: rawPlaces
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> row) =>
                ProvinceTopPlace.fromJson(row, mediaResolver: mediaResolver),
          )
          .toList(growable: false),
    );
  }
}

class RecommendRepository {
  RecommendRepository({
    SupabaseFunctionClient? functionClient,
    RecommendMediaResolver mediaResolver = MediaUrlResolver.resolve,
  }) : _functionClient = functionClient ?? SupabaseFunctionClient(),
       _mediaResolver = mediaResolver;

  final SupabaseFunctionClient _functionClient;
  final RecommendMediaResolver _mediaResolver;

  Future<List<RecommendDestination>> getPersonalizedProvinces({
    int limit = 100,
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
    return ProvinceDetail.fromJson(data, mediaResolver: _mediaResolver);
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
        (json['gallery'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .map(_resolveMedia)
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
    final String coverImage = _resolveMedia(
      json['cover_image']?.toString() ?? '',
    );
    final String imagePath = coverImage.isNotEmpty
        ? coverImage
        : (gallery.isNotEmpty ? gallery.first : '');
    final int placeCount = (json['place_count'] as num?)?.toInt() ?? 0;
    final double avgRating = (json['avg_rating'] as num?)?.toDouble() ?? 0;

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
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      gallery: gallery,
      bestMonths: const <int>[],
    );
  }

  String _resolveMedia(String rawValue) =>
      _resolveOptionalMedia(rawValue, _mediaResolver);
}

String _resolveOptionalMedia(
  Object? rawValue,
  RecommendMediaResolver mediaResolver,
) {
  final String raw = rawValue?.toString().trim() ?? '';
  return raw.isEmpty ? '' : mediaResolver(raw).trim();
}
