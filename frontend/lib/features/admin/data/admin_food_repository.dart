import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_food.dart';

class AdminFoodRepository {
  AdminFoodRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _functionName = 'admin-food';
  static const String _defaultLanguage = 'en';
  static const Duration _cacheTtl = Duration(seconds: 45);

  static DateTime? _foodsCachedAt;
  static DateTime? _typesCachedAt;
  static List<AdminFood>? _foodsCache;
  static List<FoodType>? _typesCache;

  final SupabaseClient _client;

  Future<List<AdminFood>> fetchFoods({
    String language = _defaultLanguage,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isFresh(_foodsCachedAt) && _foodsCache != null) {
      return List<AdminFood>.from(_foodsCache!);
    }

    final data = await _invokeAction(
      action: 'listFoods',
      payload: <String, dynamic>{'language': language},
    );

    final List<dynamic> rawFoods =
        (data['foods'] as List<dynamic>?) ?? <dynamic>[];
    final foods = rawFoods
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (raw) => _foodFromJson(
            Map<String, dynamic>.from(raw.cast<String, dynamic>()),
          ),
        )
        .toList(growable: false);

    _foodsCache = foods;
    _foodsCachedAt = DateTime.now();
    return List<AdminFood>.from(foods);
  }

  Future<List<FoodType>> fetchFoodTypes({
    String language = _defaultLanguage,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isFresh(_typesCachedAt) && _typesCache != null) {
      return List<FoodType>.from(_typesCache!);
    }

    final data = await _invokeAction(
      action: 'listFoodTypes',
      payload: <String, dynamic>{'language': language},
    );

    final List<dynamic> rawTypes =
        (data['foodTypes'] as List<dynamic>?) ?? <dynamic>[];
    final types = rawTypes
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (raw) => _foodTypeFromJson(
            Map<String, dynamic>.from(raw.cast<String, dynamic>()),
          ),
        )
        .toList(growable: false);

    _typesCache = types;
    _typesCachedAt = DateTime.now();
    return List<FoodType>.from(types);
  }

  Future<AdminFood> createFood({
    required AdminFood food,
    String language = _defaultLanguage,
  }) async {
    final data = await _invokeAction(
      action: 'createFood',
      payload: <String, dynamic>{
        'language': language,
        'food': _foodToJson(food, includeId: false),
      },
    );

    _invalidateFoodsCache();
    return _foodFromJson(_readMap(data, 'food'));
  }

  Future<AdminFood> updateFood({
    required AdminFood food,
    String language = _defaultLanguage,
  }) async {
    final data = await _invokeAction(
      action: 'updateFood',
      payload: <String, dynamic>{
        'language': language,
        'food': _foodToJson(food),
      },
    );

    _invalidateFoodsCache();
    return _foodFromJson(_readMap(data, 'food'));
  }

  Future<void> deleteFood(String foodId) async {
    await _invokeAction(
      action: 'deleteFood',
      payload: <String, dynamic>{'foodId': foodId},
    );
    _invalidateFoodsCache();
  }

  Future<void> upsertFoodType({
    required FoodType type,
    String language = _defaultLanguage,
  }) async {
    await _invokeAction(
      action: 'upsertFoodType',
      payload: <String, dynamic>{
        'language': language,
        'foodType': _foodTypeToJson(type),
      },
    );
    _invalidateTypesCache();
  }

  Future<void> deleteFoodType(String typeId) async {
    await _invokeAction(
      action: 'deleteFoodType',
      payload: <String, dynamic>{'typeId': typeId},
    );
    _invalidateTypesCache();
  }

  Future<void> reassignFoodType({
    required String fromTypeId,
    required String toTypeId,
  }) async {
    await _invokeAction(
      action: 'reassignFoodType',
      payload: <String, dynamic>{
        'fromTypeId': fromTypeId,
        'toTypeId': toTypeId,
      },
    );
    _invalidateFoodsCache();
  }

  Future<Map<String, dynamic>> _invokeAction({
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final Session? session = _client.auth.currentSession;
    final Map<String, String> headers = <String, String>{};
    if (session?.accessToken case final String token) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client.functions.invoke(
      _functionName,
      headers: headers.isEmpty ? null : headers,
      body: <String, dynamic>{'action': action, ...?payload},
    );

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }

    throw StateError(
      'Unexpected response from function "$_functionName" for action "$action".',
    );
  }

  Map<String, dynamic> _foodToJson(AdminFood food, {bool includeId = true}) {
    return <String, dynamic>{
      if (includeId) 'id': food.id,
      'name': food.name,
      'typeId': food.typeId,
      'city': food.city,
      'urlImage': food.urlImage,
      'description': food.description,
    };
  }

  AdminFood _foodFromJson(Map<String, dynamic> json) {
    return AdminFood(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      typeId: _readString(json, 'typeId'),
      city: _readNullableString(json, 'city') ?? 'Unknown',
      urlImage: _readNullableString(json, 'urlImage'),
      description: _readNullableString(json, 'description'),
    );
  }

  Map<String, dynamic> _foodTypeToJson(FoodType type) {
    return <String, dynamic>{
      'id': type.id,
      'label': type.label,
      'colorIndex': type.colorIndex,
    };
  }

  FoodType _foodTypeFromJson(Map<String, dynamic> json) {
    return FoodType(
      id: _readString(json, 'id'),
      label: _readString(json, 'label'),
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Expected "$key" to be a JSON object.');
  }

  String _readString(Map<String, dynamic> json, String key) {
    final String? value = _readNullableString(json, key);
    if (value == null || value.isEmpty) {
      throw StateError('Expected non-empty "$key" in function response.');
    }
    return value;
  }

  String? _readNullableString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _isFresh(DateTime? time) {
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheTtl;
  }

  static void _invalidateFoodsCache() {
    _foodsCache = null;
    _foodsCachedAt = null;
  }

  static void _invalidateTypesCache() {
    _typesCache = null;
    _typesCachedAt = null;
  }
}
