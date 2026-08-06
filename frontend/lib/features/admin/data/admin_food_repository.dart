import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_food.dart';

class AdminFoodPageResult {
  const AdminFoodPageResult({required this.foods, required this.totalCount});

  final List<AdminFood> foods;
  final int totalCount;
}

class AdminFoodRepository {
  AdminFoodRepository({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
    SupabaseTableClient? tableClient,
  }) : _clientOverride = client,
       _functionClient =
           functionClient ??
           SupabaseFunctionClient(client: client ?? Supabase.instance.client),
       _tableClient = tableClient;

  static const String _functionName = 'admin-food';
  static const String _foodTable = 'food';
  static const String _defaultLanguage = 'en';
  static const Duration _cacheTtl = Duration(seconds: 45);

  static DateTime? _typesCachedAt;
  static List<FoodType>? _typesCache;

  final SupabaseClient? _clientOverride;
  final SupabaseFunctionClient _functionClient;
  final SupabaseTableClient? _tableClient;
  _FoodTableColumns? _foodColumns;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  Future<AdminFoodPageResult> fetchFoods({
    String language = _defaultLanguage,
    required int page,
    required int pageSize,
    String query = '',
    String? typeId,
    String? sortField,
    String? sortDirection,
  }) async {
    final columns = await _resolveFoodColumns();
    final range = SupabaseTableClient.rangeForPage(
      page: page,
      pageSize: pageSize,
    );

    dynamic filter = _client.from(_foodTable).select('*');

    // Archived records remain in the database for auditability but should not
    // appear in the active admin catalogue.
    filter = filter.neq(columns.statusColumn, 'archived');

    final trimmedTypeId = typeId?.trim();
    if (trimmedTypeId != null && trimmedTypeId.isNotEmpty) {
      filter = filter.eq(columns.typeColumn, trimmedTypeId);
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      filter = filter.or(_foodSearchFilter(columns, trimmedQuery));
    }

    final sortColumn = switch (sortField) {
      'name' => columns.nameColumn,
      'city' => columns.cityColumn,
      _ => columns.idColumn,
    };
    final ascending = sortDirection != 'descending';

    final SupabasePagedRows pageRows = await _resolvedTableClient.pagedRows(
      'food page',
      () async {
        return filter
            .order(sortColumn, ascending: ascending)
            .range(range.from, range.to)
            .count(CountOption.exact);
      },
    );
    final rows = pageRows.rows;
    final cityNames = await _loadCityNames(rows, columns);
    final foods = rows
        .map((row) => _foodFromTableRow(row, columns, cityNames))
        .toList(growable: false);
    final totalCount = pageRows.totalCount ?? foods.length;

    return AdminFoodPageResult(foods: foods, totalCount: totalCount);
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

  Future<_FoodTableColumns> _resolveFoodColumns() async {
    // The production schema is migration-controlled. Avoid probing the table
    // before every first page load: that extra sequential network round-trip
    // made the admin Food screen noticeably slower and could fail independently.
    return _foodColumns ??= const _FoodTableColumns(
      idColumn: 'id_food',
      nameColumn: 'name',
      typeColumn: 'food_type_id',
      cityColumn: 'id_province',
      imageColumn: 'image_path',
      descriptionColumn: 'description',
      statusColumn: 'status',
    );
  }

  String _foodSearchFilter(_FoodTableColumns columns, String query) {
    final escaped = query.replaceAll('%', r'\%').replaceAll(',', r'\,');
    final searchableColumns = <String>{
      columns.nameColumn,
      columns.descriptionColumn,
    };
    return searchableColumns
        .map((column) => '$column.ilike.%$escaped%')
        .join(',');
  }

  Future<Map<String, String>> _loadCityNames(
    List<Map<String, dynamic>> rows,
    _FoodTableColumns columns,
  ) async {
    if (!columns.cityIsForeignKey) return const <String, String>{};

    final ids = rows
        .map((row) => _readNullableString(row, columns.cityColumn))
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, String>{};

    final lookup = columns.cityLookup;
    try {
      final lookupRows = await _resolvedTableClient.list(
        '${lookup.table} lookup',
        () async {
          return _client
              .from(lookup.table)
              .select('${lookup.idColumn}, ${lookup.nameColumn}')
              .inFilter(lookup.idColumn, ids)
              .limit(ids.length);
        },
      );
      return <String, String>{
        for (final row in lookupRows)
          if (_readNullableString(row, lookup.idColumn) != null &&
              _readNullableString(row, lookup.nameColumn) != null)
            _readNullableString(row, lookup.idColumn)!: _readNullableString(
              row,
              lookup.nameColumn,
            )!,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<Map<String, dynamic>> _invokeAction({
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    return _functionClient.invokeJson(
      _functionName,
      body: <String, dynamic>{'action': action, ...?payload},
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
      'status': food.status,
    };
  }

  AdminFood _foodFromTableRow(
    Map<String, dynamic> row,
    _FoodTableColumns columns,
    Map<String, String> cityNames,
  ) {
    final rawCity =
        _firstString(row, <String>[
          columns.cityColumn,
          'city',
          'province',
          'city_province',
        ]) ??
        'Unknown';
    final city = columns.cityIsForeignKey
        ? cityNames[rawCity] ?? rawCity
        : rawCity;

    return AdminFood(
      id:
          _firstString(row, <String>[
            columns.idColumn,
            'id_food',
            'food_id',
            'id',
          ]) ??
          '',
      name:
          _firstString(row, <String>[
            columns.nameColumn,
            'name',
            'food_name',
            'title',
          ]) ??
          'Unnamed food',
      typeId:
          _firstString(row, <String>[
            columns.typeColumn,
            'typeId',
            'food_type_id',
            'id_food_type',
            'type_id',
            'type',
          ]) ??
          'other',
      city: city.isEmpty ? 'Unknown' : city,
      urlImage: _firstString(row, <String>[
        columns.imageColumn,
        'image_path',
        'url_image',
        'image_url',
        'image',
      ]),
      description: _firstString(row, <String>[
        columns.descriptionColumn,
        'description',
        'desc',
      ]),
      status:
          _firstString(row, <String>[
            columns.statusColumn,
            'status',
            'state',
          ]) ??
          'active',
    );
  }

  AdminFood _foodFromJson(Map<String, dynamic> json) {
    return AdminFood(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      typeId: _readString(json, 'typeId'),
      city: _readNullableString(json, 'city') ?? 'Unknown',
      urlImage: _readNullableString(json, 'urlImage'),
      description: _readNullableString(json, 'description'),
      status: _readNullableString(json, 'status') ?? 'active',
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

  String? _firstString(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final value = _readNullableString(json, key);
      if (value != null) return value;
    }
    return null;
  }

  static bool _isFresh(DateTime? time) {
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheTtl;
  }

  static void _invalidateFoodsCache() {
    // Food lists are page-loaded from Supabase, so there is no full list cache.
  }

  static void _invalidateTypesCache() {
    _typesCache = null;
    _typesCachedAt = null;
  }
}

class _FoodTableColumns {
  const _FoodTableColumns({
    required this.idColumn,
    required this.nameColumn,
    required this.typeColumn,
    required this.cityColumn,
    required this.imageColumn,
    required this.descriptionColumn,
    required this.statusColumn,
  });

  final String idColumn;
  final String nameColumn;
  final String typeColumn;
  final String cityColumn;
  final String imageColumn;
  final String descriptionColumn;
  final String statusColumn;

  bool get cityIsForeignKey =>
      cityColumn == 'id_province' ||
      cityColumn == 'province_id' ||
      cityColumn == 'id_city' ||
      cityColumn == 'city_id';

  _CityLookup get cityLookup {
    if (cityColumn == 'id_province' || cityColumn == 'province_id') {
      return const _CityLookup(
        table: 'province',
        idColumn: 'id_province',
        nameColumn: 'name',
      );
    }
    return const _CityLookup(
      table: 'city_province',
      idColumn: 'id_city',
      nameColumn: 'city',
    );
  }
}

class _CityLookup {
  const _CityLookup({
    required this.table,
    required this.idColumn,
    required this.nameColumn,
  });

  final String table;
  final String idColumn;
  final String nameColumn;
}
