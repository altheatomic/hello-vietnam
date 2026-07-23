import 'dart:convert';

import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ExploreSectionsFetcher =
    Future<Map<String, dynamic>> Function({
      ExploreProvince? province,
      required int limitPerCategory,
      String? language,
    });

typedef ExploreCategoryItemsFetcher =
    Future<List<ExploreItem>> Function({
      required DetailCategory category,
      ExploreProvince? province,
      required int limit,
      required int offset,
      String? language,
    });

class ExploreCategoryPageData {
  final List<ExploreItem> items;
  final int? nextOffset;
  final String? emptyMessage;

  const ExploreCategoryPageData({
    required this.items,
    required this.nextOffset,
    this.emptyMessage,
  });

  bool get hasMore => nextOffset != null;
}

class ExploreSectionsData {
  final ExploreProvince? province;
  final List<ExploreCategory> categories;

  const ExploreSectionsData({required this.province, required this.categories});

  factory ExploreSectionsData.fromJson(Map<String, dynamic> json) {
    final List<Object?> rawCategories = json['categories'] is List
        ? (json['categories'] as List<Object?>)
        : const <Object?>[];

    return ExploreSectionsData(
      province: json['province'] is Map
          ? ExploreProvince.fromJson(
              (json['province'] as Map).map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      categories: rawCategories
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> category) => ExploreCategory.fromJson(
              category.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'province': province?.toJson(),
      'categories': categories
          .map((ExploreCategory category) => category.toJson())
          .toList(),
    };
  }
}

class ExploreRepository {
  ExploreRepository({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
    ExploreSectionsFetcher? sectionsFetcher,
    ExploreCategoryItemsFetcher? categoryItemsFetcher,
    String? Function()? languageCodeProvider,
  }) : _client = client,
       _functionClient = functionClient,
       _sectionsFetcher = sectionsFetcher,
       _categoryItemsFetcher = categoryItemsFetcher,
       _languageCodeProvider = languageCodeProvider;

  static final ExploreRepository instance = ExploreRepository();

  final SupabaseClient? _client;
  final SupabaseFunctionClient? _functionClient;
  final ExploreSectionsFetcher? _sectionsFetcher;
  final ExploreCategoryItemsFetcher? _categoryItemsFetcher;
  final String? Function()? _languageCodeProvider;

  static const List<String> _categoryOrder = <String>[
    'activities',
    'culture',
    'food',
    'local_products',
  ];
  static const String _storageKeyPrefix = 'explore_sections_cache_v1_';

  bool _isStorageReady = false;

  Future<ExploreSectionsData> loadSections({
    ExploreProvince? province,
    int limitPerCategory = 4,
  }) async {
    final String? language = _currentLanguageCode();
    final Map<String, dynamic> payload = await _fetchSectionsPayload(
      province: province,
      limitPerCategory: limitPerCategory,
      language: language,
    );
    final ExploreSectionsData sections = _parseSectionsPayload(payload);
    await _cacheSections(
      sections,
      province: province,
      limitPerCategory: limitPerCategory,
      language: language,
    );
    return sections;
  }

  Future<ExploreSectionsData?> loadCachedSections({
    ExploreProvince? province,
    int limitPerCategory = 4,
  }) async {
    await _ensureStorageReady();
    final String? language = _currentLanguageCode();
    final String? raw = app_storage.LocalStorage.instance.getString(
      _sectionsCacheKey(province, limitPerCategory, language),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return ExploreSectionsData.fromJson(
        decoded.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  ExploreSectionsData _parseSectionsPayload(Map<String, dynamic> payload) {
    final ExploreProvince? resolvedProvince = _parseProvince(
      payload['province'],
    );
    final Map<String, dynamic> sections = _asMap(
      payload['sections'],
      allowEmpty: true,
    );

    return ExploreSectionsData(
      province: resolvedProvince,
      categories: _categoryOrder
          .map((String categoryId) {
            final Map<String, dynamic> section = _asMap(
              sections[categoryId],
              allowEmpty: true,
            );
            final List<ExploreItem> items = _asList(section['items'])
                .map((Object? row) => ExploreItem.fromJson(_asMap(row)))
                .toList(growable: false);

            return ExploreCategory(
              id: categoryId,
              title: _titleForCategory(categoryId, resolvedProvince),
              description: _descriptionForCategory(
                categoryId,
                resolvedProvince,
              ),
              items: items,
              emptyMessage: _stringValue(section['emptyMessage']),
            );
          })
          .toList(growable: false),
    );
  }

  Future<Map<String, dynamic>> _fetchSectionsPayload({
    ExploreProvince? province,
    required int limitPerCategory,
    required String? language,
  }) async {
    final ExploreSectionsFetcher? sectionsFetcher = _sectionsFetcher;
    if (sectionsFetcher != null) {
      return sectionsFetcher(
        province: province,
        limitPerCategory: limitPerCategory,
        language: language,
      );
    }

    return _resolvedFunctionClient.invokeJson(
      Env.exploreFunction,
      body: <String, dynamic>{
        'action': 'getExploreSections',
        'provinceId': province?.isResolved == true ? province!.id : null,
        'limitPerCategory': limitPerCategory,
        'language': language,
      },
    );
  }

  Future<void> _cacheSections(
    ExploreSectionsData sections, {
    required ExploreProvince? province,
    required int limitPerCategory,
    required String? language,
  }) async {
    await _ensureStorageReady();
    await app_storage.LocalStorage.instance.setString(
      _sectionsCacheKey(province, limitPerCategory, language),
      jsonEncode(sections.toJson()),
    );
  }

  Future<void> _ensureStorageReady() async {
    if (_isStorageReady) {
      return;
    }
    await app_storage.LocalStorage.instance.initialize();
    _isStorageReady = true;
  }

  String _sectionsCacheKey(
    ExploreProvince? province,
    int limitPerCategory,
    String? language,
  ) {
    final String provinceKey = province?.isResolved == true
        ? province!.id
        : 'all';
    final String languageKey = _normalizedLanguageCode(language) ?? 'default';
    return '$_storageKeyPrefix${provinceKey}_${languageKey}_$limitPerCategory';
  }

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  SupabaseFunctionClient get _resolvedFunctionClient =>
      _functionClient ?? SupabaseFunctionClient(client: _resolvedClient);

  Future<List<ExploreProvince>> searchProvinces(
    String query, {
    int limit = 8,
  }) async {
    final String normalized = query.trim();
    if (normalized.isEmpty) return const <ExploreProvince>[];

    final Map<String, dynamic> payload = await _resolvedFunctionClient
        .invokeJson(
          Env.exploreFunction,
          body: <String, dynamic>{
            'action': 'searchExploreProvinces',
            'query': normalized,
            'limit': limit,
          },
        );

    return _asList(payload['items'])
        .map((Object? row) => ExploreProvince.fromJson(_asMap(row)))
        .where((ExploreProvince province) => province.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ExploreItem>> loadCategoryItems(
    DetailCategory category, {
    ExploreProvince? province,
    int limit = 40,
    int offset = 0,
  }) async {
    final ExploreCategoryPageData page = await loadCategoryPage(
      category,
      province: province,
      limit: limit,
      offset: offset,
    );
    return page.items;
  }

  Future<ExploreCategoryPageData> loadCategoryPage(
    DetailCategory category, {
    ExploreProvince? province,
    int limit = 40,
    int offset = 0,
    String? query,
  }) async {
    final String? language = _currentLanguageCode();
    final ExploreCategoryItemsFetcher? categoryItemsFetcher =
        _categoryItemsFetcher;
    if (categoryItemsFetcher != null) {
      final List<ExploreItem> items = await categoryItemsFetcher(
        category: category,
        province: province,
        limit: limit,
        offset: offset,
        language: language,
      );
      return ExploreCategoryPageData(
        items: items,
        nextOffset: items.length == limit ? offset + items.length : null,
      );
    }

    final Map<String, dynamic> payload = await _resolvedFunctionClient
        .invokeJson(
          Env.exploreFunction,
          body: <String, dynamic>{
            'action': 'getExploreCategoryItems',
            'category': category.storageKey,
            'provinceId': province?.isResolved == true ? province!.id : null,
            'limit': limit,
            'offset': offset,
            'language': language,
            if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
          },
        );

    final List<ExploreItem> items = _asList(payload['items'])
        .map((Object? row) => ExploreItem.fromJson(_asMap(row)))
        .toList(growable: false);
    return ExploreCategoryPageData(
      items: items,
      nextOffset: _nullableInt(payload['nextOffset']),
      emptyMessage: _stringValue(payload['emptyMessage']),
    );
  }

  String descriptionForCategory(
    DetailCategory category, {
    ExploreProvince? province,
  }) {
    return _descriptionForCategory(category.storageKey, province);
  }

  String titleForCategory(
    DetailCategory category, {
    ExploreProvince? province,
  }) {
    return _titleForCategory(category.storageKey, province);
  }

  Future<ExploreProvince?> resolveProvinceByName(String rawName) async {
    final String normalized = rawName.trim();
    if (normalized.isEmpty) return null;

    final List<ExploreProvince> suggestions = await searchProvinces(
      normalized,
      limit: 8,
    );
    if (suggestions.isEmpty) return null;

    final String normalizedQuery = _normalizeText(normalized);
    for (final ExploreProvince suggestion in suggestions) {
      if (_normalizeText(suggestion.name) == normalizedQuery) {
        return suggestion;
      }
    }

    if (suggestions.length == 1) {
      return suggestions.first;
    }
    return null;
  }

  ExploreProvince? _parseProvince(Object? raw) {
    if (raw == null) return null;
    final Map<String, dynamic> json = _asMap(raw);
    if (json.isEmpty) return null;
    final ExploreProvince province = ExploreProvince.fromJson(json);
    return province.name.isEmpty ? null : province;
  }

  static String _titleForCategory(
    String categoryId,
    ExploreProvince? province,
  ) {
    final String label = _labelForCategory(categoryId);
    if (province == null) return label;
    return '$label in ${province.name}';
  }

  static String _descriptionForCategory(
    String categoryId,
    ExploreProvince? province,
  ) {
    if (province != null) {
      switch (categoryId) {
        case 'activities':
          return 'Featured activities in ${province.name}';
        case 'culture':
          return 'Cultural highlights in ${province.name}';
        case 'food':
          return 'Local food to explore in ${province.name}';
        case 'local_products':
          return 'Local products from ${province.name}';
      }
    }

    switch (categoryId) {
      case 'activities':
        return 'Hands-on experiences and cultural activities';
      case 'culture':
        return 'Traditional customs, heritage, and cultural practices';
      case 'food':
        return 'Local dishes and culinary specialties from different regions';
      case 'local_products':
        return 'Traditional goods and handcrafted regional products';
      default:
        return '';
    }
  }

  static String _labelForCategory(String categoryId) {
    switch (categoryId) {
      case 'activities':
        return 'Activities';
      case 'culture':
        return 'Culture';
      case 'food':
        return 'Food';
      case 'local_products':
        return 'Local Products';
      default:
        return categoryId;
    }
  }

  Map<String, dynamic> _asMap(Object? raw, {bool allowEmpty = false}) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    if (allowEmpty && raw == null) return <String, dynamic>{};
    throw Exception('Invalid Explore response.');
  }

  List<Object?> _asList(Object? raw) {
    if (raw is List) return raw.cast<Object?>();
    return const <Object?>[];
  }

  String? _stringValue(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String? _currentLanguageCode() {
    final String raw =
        _languageCodeProvider?.call() ??
        AppLanguageController.instance.languageCode;
    return _normalizedLanguageCode(raw);
  }

  String? _normalizedLanguageCode(String? value) {
    final String trimmed = value?.trim().toLowerCase() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _normalizeText(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('đ', 'd')
        .replaceAllMapped(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), (_) => 'a')
        .replaceAllMapped(RegExp(r'[èéẹẻẽêềếệểễ]'), (_) => 'e')
        .replaceAllMapped(RegExp(r'[ìíịỉĩ]'), (_) => 'i')
        .replaceAllMapped(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), (_) => 'o')
        .replaceAllMapped(RegExp(r'[ùúụủũưừứựửữ]'), (_) => 'u')
        .replaceAllMapped(RegExp(r'[ỳýỵỷỹ]'), (_) => 'y');
  }
}
