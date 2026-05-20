import 'package:supabase_flutter/supabase_flutter.dart';

enum FavoriteType {
  city,
  place,
  food;

  String get dbValue {
    switch (this) {
      case FavoriteType.city:
        return 'city';
      case FavoriteType.place:
        return 'place';
      case FavoriteType.food:
        return 'food';
    }
  }

  static FavoriteType? tryParse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'city':
        return FavoriteType.city;
      case 'place':
        return FavoriteType.place;
      case 'food':
        return FavoriteType.food;
      default:
        return null;
    }
  }
}

class WishlistRepositoryItem {
  const WishlistRepositoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final FavoriteType type;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime? createdAt;
}

class WishlistRepository {
  WishlistRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _functionName = 'wishlist';
  final SupabaseClient _client;

  Future<List<WishlistRepositoryItem>> fetchWishlist({
    String language = 'en',
  }) async {
    final data = await _invokeAction(
      action: 'listWishlist',
      payload: <String, dynamic>{'language': language},
    );

    final rawItems = (data['items'] as List<dynamic>?) ?? const <dynamic>[];
    return rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => _itemFromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<bool> isFavoriteByRawId({
    required FavoriteType type,
    required String rawItemId,
    String? fallbackName,
  }) async {
    final data = await _invokeAction(
      action: 'isFavoriteByRawId',
      payload: <String, dynamic>{
        'type': type.dbValue,
        'rawItemId': rawItemId,
        'fallbackName': fallbackName,
      },
    );
    return data['isFavorite'] == true;
  }

  Future<bool> toggleFavoriteByRawId({
    required FavoriteType type,
    required String rawItemId,
    String? fallbackName,
  }) async {
    final data = await _invokeAction(
      action: 'toggleFavoriteByRawId',
      payload: <String, dynamic>{
        'type': type.dbValue,
        'rawItemId': rawItemId,
        'fallbackName': fallbackName,
      },
    );
    return data['isFavorite'] == true;
  }

  Future<void> setFavorite({
    required String itemId,
    required FavoriteType type,
    required bool isFavorite,
  }) async {
    await _invokeAction(
      action: 'setFavorite',
      payload: <String, dynamic>{
        'type': type.dbValue,
        'itemId': itemId,
        'isFavorite': isFavorite,
      },
    );
  }

  Future<Map<String, dynamic>> _invokeAction({
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final session = _client.auth.currentSession;
    final headers = <String, String>{};
    if (session?.accessToken case final String token) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client.functions.invoke(
      _functionName,
      headers: headers.isEmpty ? null : headers,
      body: <String, dynamic>{'action': action, ...?payload},
    );

    final raw = response.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    throw StateError(
      'Unexpected response from function "$_functionName" for action "$action".',
    );
  }

  WishlistRepositoryItem _itemFromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final typeRaw = _requiredString(json, 'type');
    final type = FavoriteType.tryParse(typeRaw);
    if (type == null) {
      throw StateError('Unsupported favorite type: "$typeRaw".');
    }

    return WishlistRepositoryItem(
      id: id,
      type: type,
      title: _requiredString(json, 'title'),
      description: _readNullableString(json, 'description') ?? '',
      imageUrl: _readNullableString(json, 'imageUrl'),
      createdAt: DateTime.tryParse(
        _readNullableString(json, 'createdAt') ?? '',
      ),
    );
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = _readNullableString(json, key);
    if (value == null || value.isEmpty) {
      throw StateError('Expected non-empty "$key" in function response.');
    }
    return value;
  }

  String? _readNullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
