import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.tagMatch = 0.0,
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

  factory ProvinceTopPlace.fromJson(Map<String, dynamic> j) =>
      ProvinceTopPlace(
        idPlace:        j['id_place'] as String,
        name:           j['name'] as String? ?? '',
        address:        j['address'] as String?,
        coverImage:     j['cover_image'] as String?,
        galleryUrl:     j['gallery_url'] as String?,
        averageRating:  (j['average_rating'] as num?)?.toDouble(),
        reviewCount:    (j['review_count'] as num?)?.toInt(),
        subcategoryName: j['subcategory_name'] as String?,
        tagMatch:       (j['tag_match'] as num?)?.toDouble() ?? 0.0,
      );
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

  factory ProvinceDetail.fromJson(Map<String, dynamic> j) {
    final raw = j['top_places'] as List<dynamic>? ?? <dynamic>[];
    return ProvinceDetail(
      idProvince: j['id_province'] as String? ?? '',
      name:       j['name'] as String? ?? '',
      avgRating:  (j['avg_rating'] as num?)?.toDouble() ?? 0.0,
      placeCount: (j['place_count'] as num?)?.toInt() ?? 0,
      topPlaces:  raw
          .whereType<Map<String, dynamic>>()
          .map(ProvinceTopPlace.fromJson)
          .toList(),
    );
  }
}

class RecommendRepository {
  static const String _baseUrl = 'http://localhost:8000';
  static const String _testUserId = 'e4bb33fb-5f1b-49a6-9a00-93c67183afde';

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? _testUserId;

  Future<List<RecommendDestination>> getPersonalizedProvinces({
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/recommend/provinces').replace(
      queryParameters: {
        'id_user': _userId,
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'Recommend API error ${response.statusCode}: ${response.body}',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw StateError('Unexpected response format from recommend API.');
    }
    final raw = body['provinces'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_fromJson)
        .toList();
  }

  RecommendDestination _fromJson(Map<String, dynamic> p) {
    final galleryRaw = p['gallery'] as List<dynamic>? ?? <dynamic>[];
    final gallery = galleryRaw.whereType<String>().toList();
    final coverImage =
        (p['cover_image'] as String?) ??
        (gallery.isNotEmpty ? gallery.first : '');
    final placeCount = (p['place_count'] as num?)?.toInt() ?? 0;
    final avgRating = (p['avg_rating'] as num?)?.toDouble() ?? 0.0;

    return RecommendDestination(
      id: p['id_province'] as String,
      name: p['name'] as String,
      shortDescription: '$placeCount places · ⭐ $avgRating',
      description: '',
      imagePath: coverImage,
      rating: (p['final_score'] as num?)?.toDouble() ?? 0.0,
      gallery: gallery,
      bestMonths: const <int>[],
    );
  }

  Future<ProvinceDetail> getProvinceDetail({
    required String idProvince,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/recommend/province/$idProvince').replace(
      queryParameters: {
        'id_user': _userId,
        'limit':   limit.toString(),
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'Province detail API error ${response.statusCode}: ${response.body}',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw StateError('Unexpected response format from province detail API.');
    }
    return ProvinceDetail.fromJson(body);
  }
}
