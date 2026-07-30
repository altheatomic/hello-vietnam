import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/media/media_url_resolver.dart';
import '../domain/destination.dart';
import '../domain/dish.dart';

typedef HomeRpcInvoker = Future<Object?> Function(int limit);

class HomeFeaturedContent {
  const HomeFeaturedContent({required this.destinations, required this.dishes});

  final List<Destination> destinations;
  final List<Dish> dishes;
}

class HomeRepository {
  HomeRepository({
    SupabaseClient? client,
    HomeRpcInvoker? rpcInvoker,
    String mediaPublicBaseUrl = Env.cloudflareMediaPublicBaseUrl,
  }) : _clientOverride = client,
       _rpcInvoker = rpcInvoker,
       _mediaPublicBaseUrl = mediaPublicBaseUrl;

  final SupabaseClient? _clientOverride;
  final HomeRpcInvoker? _rpcInvoker;
  final String _mediaPublicBaseUrl;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<HomeFeaturedContent> fetchFeaturedContent({int limit = 4}) async {
    final Object? raw = await (_rpcInvoker?.call(limit) ??
        _client.rpc(
          'get_home_featured_content',
          params: <String, Object?>{'p_limit': limit},
        ));
    final Map<String, dynamic> payload = _asMap(raw);
    return HomeFeaturedContent(
      destinations: _asRows(
        payload['destinations'],
      ).map(_destinationFromRow).toList(growable: false),
      dishes: _asRows(payload['dishes']).map(_dishFromRow).toList(
        growable: false,
      ),
    );
  }

  Destination _destinationFromRow(Map<String, dynamic> row) {
    return Destination(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      description: row['description']?.toString(),
      imagePath: _resolveMedia(row['image_path']),
      rating: (row['rating'] as num?)?.toDouble(),
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  Dish _dishFromRow(Map<String, dynamic> row) {
    return Dish(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      imagePath: _resolveMedia(row['image_path']),
      rating: (row['rating'] as num?)?.toDouble(),
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  String _resolveMedia(Object? raw) => MediaUrlResolver.resolve(
    raw?.toString() ?? '',
    publicBaseUrl: _mediaPublicBaseUrl,
  );

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) return <String, dynamic>{};
    return raw.map<String, dynamic>(
      (Object? key, Object? value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }

  static List<Map<String, dynamic>> _asRows(Object? raw) {
    if (raw is! List<Object?>) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map<Map<String, dynamic>>(
          (Map<Object?, Object?> row) => row.map<String, dynamic>(
            (Object? key, Object? value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }
}
