import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_food.dart';

class AdminFoodRepository {
  AdminFoodRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String _foodTable = 'food';
  static const String _foodTranslationTable = 'food_translation';
  static const String _foodTypeTranslationTable = 'food_type_translation';
  static const String _foodTypeTable = 'food_type';
  static const String _cityTable = 'city_province';

  static const String _defaultLanguage = 'en';

  final SupabaseClient _client;

  String _foodIdColumn = 'id_food';
  String _foodTypeColumn = 'food_type_id';
  String _foodCityColumn = 'id_city';
  String _foodImageColumn = 'image_path';
  String _foodNameColumn = 'name';
  String _foodDescriptionColumn = 'description';
  bool _foodCityIsForeignKey = true;

  _FoodTranslationHints? _foodTranslationHints;
  _FoodTypeTranslationHints? _foodTypeTranslationHints;
  _FoodTypeHints? _foodTypeHints;
  _CityHints? _cityHints;

  Future<List<AdminFood>> fetchFoods({
    String language = _defaultLanguage,
  }) async {
    final List<Map<String, dynamic>> foodRows = await _selectRows(_foodTable);
    _hydrateFoodColumnsFromRows(foodRows);

    final _FoodTranslationHints foodTransHints =
        await _ensureFoodTranslationHints();
    final List<Map<String, dynamic>> preferredFoodTranslations =
        await _loadPreferredTranslationsByEntity(
      table: _foodTranslationTable,
      entityIdColumn: foodTransHints.foodIdColumn,
      languageColumn: foodTransHints.languageColumn,
      preferredLanguage: language,
    );

    final Map<String, Map<String, dynamic>> foodTranslationByFoodId =
        _indexByStringKey(
      rows: preferredFoodTranslations,
      idColumn: foodTransHints.foodIdColumn,
    );

    Map<String, String> cityNameById = <String, String>{};
    if (_foodCityIsForeignKey) {
      final _CityHints cityHints = await _ensureCityHints();
      final List<Map<String, dynamic>> cityRows = await _selectRows(_cityTable);
      cityNameById = _indexNameById(
        rows: cityRows,
        idColumn: cityHints.idColumn,
        nameColumn: cityHints.nameColumn,
      );
    }

    final List<AdminFood> foods = <AdminFood>[];
    for (final Map<String, dynamic> row in foodRows) {
      final String? foodId = _stringValue(row[_foodIdColumn]);
      if (foodId == null || foodId.isEmpty) continue;

      final Map<String, dynamic>? trans = foodTranslationByFoodId[foodId];
      final String cityName = _foodCityIsForeignKey
          ? (cityNameById[_stringValue(row[_foodCityColumn]) ?? ''] ??
              _stringValue(row['city']) ??
              _stringValue(row['city_province']) ??
              '')
          : (_stringValue(row[_foodCityColumn]) ??
              _stringValue(row['city']) ??
              _stringValue(row['city_province']) ??
              '');

      final String name =
          _stringValue(trans?[foodTransHints.nameColumn]) ??
              _stringValue(row[_foodNameColumn]) ??
              _stringValue(row['name']) ??
              'Unnamed food';

      foods.add(
        AdminFood(
          id: foodId,
          name: name,
          typeId: _stringValue(row[_foodTypeColumn]) ??
              _stringValue(row['type']) ??
              '',
          city: cityName,
          urlImage: _stringValue(row[_foodImageColumn]),
          description: _stringValue(trans?[foodTransHints.descriptionColumn]) ??
              _stringValue(row[_foodDescriptionColumn]) ??
              _stringValue(row['description']),
        ),
      );
    }

    return foods;
  }

  Future<List<FoodType>> fetchFoodTypes({
    String language = _defaultLanguage,
  }) async {
    final _FoodTypeTranslationHints hints =
        await _ensureFoodTypeTranslationHints();

    final List<Map<String, dynamic>> preferredTypeTranslations =
        await _loadPreferredTranslationsByEntity(
      table: _foodTypeTranslationTable,
      entityIdColumn: hints.typeIdColumn,
      languageColumn: hints.languageColumn,
      preferredLanguage: language,
    );

    final Map<String, FoodType> uniqueById = <String, FoodType>{};
    for (final Map<String, dynamic> row in preferredTypeTranslations) {
      final String? id = _stringValue(row[hints.typeIdColumn]);
      final String? label = _stringValue(row[hints.nameColumn]);
      if (id == null || id.isEmpty || label == null || label.isEmpty) continue;

      uniqueById[id] = FoodType(
        id: id,
        label: label,
        colorIndex: _colorIndexForTypeId(id),
      );
    }

    final List<FoodType> types = uniqueById.values.toList()
      ..sort(
        (FoodType a, FoodType b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
    return types;
  }

  Future<AdminFood> createFood({
    required AdminFood food,
    String language = _defaultLanguage,
  }) async {
    await _ensureFoodColumns();
    final dynamic cityValue = _foodCityIsForeignKey
        ? await _resolveCityId(food.city)
        : _cleanNullableText(food.city);

    final Map<String, dynamic> payload = <String, dynamic>{
      _foodNameColumn: food.name,
      _foodDescriptionColumn: _cleanNullableText(food.description),
      _foodTypeColumn: food.typeId,
      _foodCityColumn: cityValue,
      _foodImageColumn: _cleanNullableText(food.urlImage),
    };

    final Map<String, dynamic> inserted =
        await _client.from(_foodTable).insert(payload).select('*').single();

    final String? foodId = _stringValue(inserted[_foodIdColumn]) ??
        _stringValue(inserted['id_food']) ??
        _stringValue(inserted['id']);
    if (foodId == null || foodId.isEmpty) {
      throw StateError('Create food succeeded but no id was returned.');
    }

    try {
      await _insertFoodTranslation(
        foodId: foodId,
        language: language,
        name: food.name,
        description: food.description,
      );
    } catch (e) {
      // Keep data consistent: if translation creation fails, rollback new food row.
      await _client.from(_foodTable).delete().eq(_foodIdColumn, foodId);
      rethrow;
    }

    return food.copyWith(id: foodId);
  }

  Future<AdminFood> updateFood({
    required AdminFood food,
    String language = _defaultLanguage,
  }) async {
    await _ensureFoodColumns();
    final dynamic cityValue = _foodCityIsForeignKey
        ? await _resolveCityId(food.city)
        : _cleanNullableText(food.city);

    final Map<String, dynamic> payload = <String, dynamic>{
      _foodNameColumn: food.name,
      _foodDescriptionColumn: _cleanNullableText(food.description),
      _foodTypeColumn: food.typeId,
      _foodCityColumn: cityValue,
      _foodImageColumn: _cleanNullableText(food.urlImage),
    };

    await _client
        .from(_foodTable)
        .update(payload)
        .eq(_foodIdColumn, food.id);

    await _upsertFoodTranslation(
      foodId: food.id,
      language: language,
      name: food.name,
      description: food.description,
    );

    return food;
  }

  Future<void> deleteFood(String foodId) async {
    final _FoodTranslationHints hints = await _ensureFoodTranslationHints();

    await _client
        .from(_foodTranslationTable)
        .delete()
        .eq(hints.foodIdColumn, foodId);

    await _client.from(_foodTable).delete().eq(_foodIdColumn, foodId);
  }

  Future<void> upsertFoodType({
    required FoodType type,
    String language = _defaultLanguage,
  }) async {
    await _ensureFoodTypeBaseRowExists(type.id, label: type.label);

    final _FoodTypeTranslationHints hints =
        await _ensureFoodTypeTranslationHints();

    final Map<String, dynamic> insertPayload = <String, dynamic>{
      hints.typeIdColumn: type.id,
      hints.nameColumn: type.label,
    };
    if (hints.languageColumn != null) {
      insertPayload[hints.languageColumn!] = language;
    }

    dynamic findQuery = _client
        .from(_foodTypeTranslationTable)
        .select('*')
        .eq(hints.typeIdColumn, type.id);
    if (hints.languageColumn != null) {
      findQuery = findQuery.eq(hints.languageColumn!, language);
    }
    final List<dynamic> existingRows = await findQuery.limit(1);
    final bool exists = existingRows.isNotEmpty;

    if (exists) {
      final Map<String, dynamic> updatePayload = <String, dynamic>{
        hints.nameColumn: type.label,
      };
      dynamic updateQuery = _client
          .from(_foodTypeTranslationTable)
          .update(updatePayload)
          .eq(hints.typeIdColumn, type.id);
      if (hints.languageColumn != null) {
        updateQuery = updateQuery.eq(hints.languageColumn!, language);
      }
      await updateQuery;
      return;
    }

    await _client.from(_foodTypeTranslationTable).insert(insertPayload);
  }

  Future<void> deleteFoodType(String typeId) async {
    final _FoodTypeTranslationHints hints =
        await _ensureFoodTypeTranslationHints();

    await _client
        .from(_foodTypeTranslationTable)
        .delete()
        .eq(hints.typeIdColumn, typeId);

    final _FoodTypeHints baseHints = await _ensureFoodTypeHints();
    await _client
        .from(_foodTypeTable)
        .delete()
        .eq(baseHints.idColumn, typeId);
  }

  Future<void> reassignFoodType({
    required String fromTypeId,
    required String toTypeId,
  }) async {
    await _ensureFoodColumns();

    await _client
        .from(_foodTable)
        .update(<String, dynamic>{_foodTypeColumn: toTypeId})
        .eq(_foodTypeColumn, fromTypeId);
  }

  Future<void> _upsertFoodTranslation({
    required String foodId,
    required String language,
    required String name,
    String? description,
  }) async {
    final _FoodTranslationHints hints = await _ensureFoodTranslationHints();

    final Map<String, dynamic> insertPayload = <String, dynamic>{
      hints.foodIdColumn: foodId,
      hints.nameColumn: name,
      hints.descriptionColumn: _cleanNullableText(description),
    };
    if (hints.languageColumn != null) {
      insertPayload[hints.languageColumn!] = language;
    }

    dynamic findQuery = _client
        .from(_foodTranslationTable)
        .select('*')
        .eq(hints.foodIdColumn, foodId);
    if (hints.languageColumn != null) {
      findQuery = findQuery.eq(hints.languageColumn!, language);
    }
    final List<dynamic> existingRows = await findQuery.limit(1);
    final bool exists = existingRows.isNotEmpty;

    if (exists) {
      final Map<String, dynamic> updatePayload = <String, dynamic>{
        hints.nameColumn: name,
        hints.descriptionColumn: _cleanNullableText(description),
      };
      dynamic updateQuery = _client
          .from(_foodTranslationTable)
          .update(updatePayload)
          .eq(hints.foodIdColumn, foodId);
      if (hints.languageColumn != null) {
        updateQuery = updateQuery.eq(hints.languageColumn!, language);
      }
      await updateQuery;
      return;
    }

    await _client.from(_foodTranslationTable).insert(insertPayload);
  }

  Future<void> _insertFoodTranslation({
    required String foodId,
    required String language,
    required String name,
    String? description,
  }) async {
    final _FoodTranslationHints hints = await _ensureFoodTranslationHints();

    final Map<String, dynamic> insertPayload = <String, dynamic>{
      hints.foodIdColumn: foodId,
      hints.nameColumn: name,
      hints.descriptionColumn: _cleanNullableText(description),
    };
    if (hints.languageColumn != null) {
      insertPayload[hints.languageColumn!] = language;
    }

    await _client.from(_foodTranslationTable).insert(insertPayload);
  }

  Future<void> _ensureFoodColumns() async {
    final List<Map<String, dynamic>> rows =
        await _client.from(_foodTable).select('*').limit(1);
    _hydrateFoodColumnsFromRows(rows);
  }

  void _hydrateFoodColumnsFromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return;
    final Map<String, dynamic> sample = rows.first;

    _foodIdColumn = _pickExistingColumn(
      row: sample,
      candidates: const <String>['id_food', 'food_id', 'id'],
      fallback: _foodIdColumn,
    );
    _foodTypeColumn = _pickExistingColumn(
      row: sample,
      candidates: const <String>[
        'food_type_id',
        'id_food_type',
        'type_id',
        'type',
      ],
      fallback: _foodTypeColumn,
    );
    _foodCityColumn = _pickExistingColumn(
      row: sample,
      candidates: const <String>[
        'id_city',
        'city_id',
        'city_province',
        'city',
        'province',
      ],
      fallback: _foodCityColumn,
    );
    _foodCityIsForeignKey =
        _foodCityColumn == 'id_city' || _foodCityColumn == 'city_id';
    _foodImageColumn = _pickExistingColumn(
      row: sample,
      candidates: const <String>[
        'image_path',
        'url_image',
        'image_url',
        'image',
      ],
      fallback: _foodImageColumn,
    );
    _foodNameColumn = _pickExistingColumn(
      row: sample,
      candidates: const <String>[
        'name',
        'food_name',
        'title',
      ],
      fallback: _foodNameColumn,
    );
    _foodDescriptionColumn = _pickExistingColumn(
      row: sample,
      candidates: const <String>[
        'description',
        'desc',
      ],
      fallback: _foodDescriptionColumn,
    );
  }

  Future<_FoodTranslationHints> _ensureFoodTranslationHints() async {
    if (_foodTranslationHints != null) return _foodTranslationHints!;

    final List<Map<String, dynamic>> rows =
        await _client.from(_foodTranslationTable).select('*').limit(1);
    final Map<String, dynamic> sample =
        rows.isEmpty ? <String, dynamic>{} : rows.first;

    _foodTranslationHints = _FoodTranslationHints(
      foodIdColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>['id_food', 'food_id'],
        fallback: 'food_id',
      ),
      languageColumn: _pickOptionalColumn(
        row: sample,
        candidates: const <String>[
          'lang_code',
          'language',
          'lang',
          'locale',
          'language_code',
        ],
      ),
      nameColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>['name', 'label', 'title'],
        fallback: 'name',
      ),
      descriptionColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>['description', 'desc'],
        fallback: 'description',
      ),
    );
    return _foodTranslationHints!;
  }

  Future<_FoodTypeTranslationHints> _ensureFoodTypeTranslationHints() async {
    if (_foodTypeTranslationHints != null) return _foodTypeTranslationHints!;

    final List<Map<String, dynamic>> rows =
        await _client.from(_foodTypeTranslationTable).select('*').limit(1);
    final Map<String, dynamic> sample =
        rows.isEmpty ? <String, dynamic>{} : rows.first;

    _foodTypeTranslationHints = _FoodTypeTranslationHints(
      typeIdColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>[
          'food_type_id',
          'id_food_type',
          'type_id',
          'type',
        ],
        fallback: 'food_type_id',
      ),
      languageColumn: _pickOptionalColumn(
        row: sample,
        candidates: const <String>[
          'lang_code',
          'language',
          'lang',
          'locale',
          'language_code',
        ],
      ),
      nameColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>['name', 'label', 'title'],
        fallback: 'name',
      ),
    );
    return _foodTypeTranslationHints!;
  }

  Future<_FoodTypeHints> _ensureFoodTypeHints() async {
    if (_foodTypeHints != null) return _foodTypeHints!;

    final List<Map<String, dynamic>> rows =
        await _client.from(_foodTypeTable).select('*').limit(1);
    final Map<String, dynamic> sample =
        rows.isEmpty ? <String, dynamic>{} : rows.first;
    final bool tableLooksEmpty = rows.isEmpty;

    final String? detectedTypeColumn = _pickOptionalColumn(
      row: sample,
      candidates: const <String>[
        'type',
        'food_type',
        'category_type',
      ],
    );
    final String? fallbackTypeColumn = tableLooksEmpty
        ? 'type'
        : null;

    _foodTypeHints = _FoodTypeHints(
      idColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>[
          'food_type_id',
          'id_food_type',
          'type_id',
          'id',
        ],
        fallback: 'food_type_id',
      ),
      codeColumn: _pickOptionalColumn(
        row: sample,
        candidates: const <String>[
          'code',
          'type_code',
          'slug',
        ],
      ),
      typeColumn: detectedTypeColumn ?? fallbackTypeColumn,
      nameColumn: _pickOptionalColumn(
        row: sample,
        candidates: const <String>[
          'name',
          'label',
          'title',
        ],
      ),
    );
    return _foodTypeHints!;
  }

  Future<_CityHints> _ensureCityHints() async {
    if (_cityHints != null) return _cityHints!;

    final List<Map<String, dynamic>> rows =
        await _client.from(_cityTable).select('*').limit(1);
    final Map<String, dynamic> sample =
        rows.isEmpty ? <String, dynamic>{} : rows.first;

    _cityHints = _CityHints(
      idColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>['id_city', 'city_id', 'id'],
        fallback: 'id_city',
      ),
      nameColumn: _pickExistingColumn(
        row: sample,
        candidates: const <String>['name', 'city', 'province'],
        fallback: 'name',
      ),
    );
    return _cityHints!;
  }

  Future<List<Map<String, dynamic>>> _loadPreferredTranslationsByEntity({
    required String table,
    required String entityIdColumn,
    required String? languageColumn,
    required String preferredLanguage,
  }) async {
    final List<Map<String, dynamic>> rows = await _selectRows(table);
    if (rows.isEmpty) return rows;

    final bool hasLanguageColumn =
        languageColumn != null && rows.first.containsKey(languageColumn);
    final Map<String, List<Map<String, dynamic>>> grouped =
        <String, List<Map<String, dynamic>>>{};

    for (final Map<String, dynamic> row in rows) {
      final String? entityId = _stringValue(row[entityIdColumn]);
      if (entityId == null || entityId.isEmpty) continue;
      grouped.putIfAbsent(entityId, () => <Map<String, dynamic>>[]).add(row);
    }

    final List<Map<String, dynamic>> picked = <Map<String, dynamic>>[];
    for (final List<Map<String, dynamic>> groupRows in grouped.values) {
      if (!hasLanguageColumn) {
        picked.add(groupRows.first);
        continue;
      }

      Map<String, dynamic>? exact;
      Map<String, dynamic>? english;
      for (final Map<String, dynamic> row in groupRows) {
        final String? lang =
            _stringValue(row[languageColumn])?.toLowerCase();
        if (lang == null) continue;
        if (lang == preferredLanguage.toLowerCase()) {
          exact = row;
          break;
        }
        if (lang == 'en' && english == null) {
          english = row;
        }
      }

      picked.add(exact ?? english ?? groupRows.first);
    }

    return picked;
  }

  Future<List<Map<String, dynamic>>> _selectRows(String table) async {
    final List<dynamic> raw = await _client.from(table).select('*');
    return raw.cast<Map<String, dynamic>>();
  }

  Future<String> _resolveCityId(String cityName) async {
    final _CityHints hints = await _ensureCityHints();
    final String normalizedCity = cityName.trim();

    if (normalizedCity.isEmpty) {
      throw ArgumentError('City/Province cannot be empty.');
    }

    final List<Map<String, dynamic>> cityRows = await _client
        .from(_cityTable)
        .select('*')
        .ilike(hints.nameColumn, normalizedCity)
        .limit(1);

    if (cityRows.isNotEmpty) {
      final String? id = _stringValue(cityRows.first[hints.idColumn]);
      if (id != null && id.isNotEmpty) return id;
    }

    final Map<String, dynamic> inserted = await _client
        .from(_cityTable)
        .insert(<String, dynamic>{hints.nameColumn: normalizedCity})
        .select('*')
        .single();

    final String? insertedId = _stringValue(inserted[hints.idColumn]);
    if (insertedId == null || insertedId.isEmpty) {
      throw StateError('City insert succeeded but no city id was returned.');
    }
    return insertedId;
  }

  Future<void> _ensureFoodTypeBaseRowExists(
    String typeId, {
    String? label,
  }) async {
    final _FoodTypeHints hints = await _ensureFoodTypeHints();

    final List<Map<String, dynamic>> existingRows = await _client
        .from(_foodTypeTable)
        .select('*')
        .eq(hints.idColumn, typeId)
        .limit(1);
    if (existingRows.isNotEmpty) return;

    final Map<String, dynamic> insertPayload = <String, dynamic>{
      hints.idColumn: typeId,
    };
    final String normalizedLabel = (label ?? '').trim();
    if (hints.codeColumn != null) {
      insertPayload[hints.codeColumn!] = 'type-${typeId.substring(0, 8)}';
    }
    if (hints.typeColumn != null && normalizedLabel.isNotEmpty) {
      insertPayload[hints.typeColumn!] = normalizedLabel;
    }
    if (hints.nameColumn != null &&
        hints.nameColumn != hints.typeColumn &&
        normalizedLabel.isNotEmpty) {
      insertPayload[hints.nameColumn!] = normalizedLabel;
    }

    await _client.from(_foodTypeTable).insert(insertPayload);
  }

  Map<String, Map<String, dynamic>> _indexByStringKey({
    required List<Map<String, dynamic>> rows,
    required String idColumn,
  }) {
    final Map<String, Map<String, dynamic>> output =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> row in rows) {
      final String? key = _stringValue(row[idColumn]);
      if (key == null || key.isEmpty) continue;
      output[key] = row;
    }
    return output;
  }

  Map<String, String> _indexNameById({
    required List<Map<String, dynamic>> rows,
    required String idColumn,
    required String nameColumn,
  }) {
    final Map<String, String> output = <String, String>{};
    for (final Map<String, dynamic> row in rows) {
      final String? id = _stringValue(row[idColumn]);
      final String? name = _stringValue(row[nameColumn]);
      if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
      output[id] = name;
    }
    return output;
  }

  String _pickExistingColumn({
    required Map<String, dynamic> row,
    required List<String> candidates,
    required String fallback,
  }) {
    for (final String key in candidates) {
      if (row.containsKey(key)) return key;
    }
    return fallback;
  }

  String? _pickOptionalColumn({
    required Map<String, dynamic> row,
    required List<String> candidates,
  }) {
    for (final String key in candidates) {
      if (row.containsKey(key)) return key;
    }
    return null;
  }

  int _colorIndexForTypeId(String typeId) {
    final int hash = typeId.codeUnits.fold<int>(0, (int acc, int c) {
      return (acc * 31 + c) & 0x7fffffff;
    });
    return hash % foodTypeColorPalette.length;
  }

  String? _cleanNullableText(String? value) {
    final String? cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final String s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}

class _FoodTranslationHints {
  const _FoodTranslationHints({
    required this.foodIdColumn,
    required this.languageColumn,
    required this.nameColumn,
    required this.descriptionColumn,
  });

  final String foodIdColumn;
  final String? languageColumn;
  final String nameColumn;
  final String descriptionColumn;
}

class _FoodTypeTranslationHints {
  const _FoodTypeTranslationHints({
    required this.typeIdColumn,
    required this.languageColumn,
    required this.nameColumn,
  });

  final String typeIdColumn;
  final String? languageColumn;
  final String nameColumn;
}

class _CityHints {
  const _CityHints({required this.idColumn, required this.nameColumn});

  final String idColumn;
  final String nameColumn;
}

class _FoodTypeHints {
  const _FoodTypeHints({
    required this.idColumn,
    required this.codeColumn,
    required this.typeColumn,
    required this.nameColumn,
  });

  final String idColumn;
  final String? codeColumn;
  final String? typeColumn;
  final String? nameColumn;
}
