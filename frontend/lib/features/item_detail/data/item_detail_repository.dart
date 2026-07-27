import 'dart:async';

import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/media/media_url_resolver.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemDetailRepository {
  ItemDetailRepository({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
    String? Function()? languageCodeProvider,
  }) : _client = client,
       _functionClient = functionClient,
       _languageCodeProvider = languageCodeProvider;

  static final ItemDetailRepository instance = ItemDetailRepository();
  static const Duration _cacheTtl = Duration(minutes: 15);
  static final Map<String, _CachedItemDetail> _cache =
      <String, _CachedItemDetail>{};
  static final Map<String, Future<ItemDetail>> _inFlight =
      <String, Future<ItemDetail>>{};

  final SupabaseClient? _client;
  final SupabaseFunctionClient? _functionClient;
  final String? Function()? _languageCodeProvider;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  SupabaseFunctionClient get _resolvedFunctionClient =>
      _functionClient ?? SupabaseFunctionClient(client: _resolvedClient);

  Future<ItemDetail> load(ItemDetailRequest request) async {
    final String language =
        (_languageCodeProvider?.call() ??
                AppLanguageController.instance.languageCode)
            .trim()
            .toLowerCase();
    final String cacheKey =
        '${request.category.storageKey}:${request.id}:$language';
    final _CachedItemDetail? cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.detail;
    }
    final Future<ItemDetail>? pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    late final Future<ItemDetail> future;
    future = _loadUncached(request, language).then(
      (ItemDetail detail) {
        _cache[cacheKey] = _CachedItemDetail(detail);
        _inFlight.remove(cacheKey);
        return detail;
      },
      onError: (Object error, StackTrace stackTrace) {
        _inFlight.remove(cacheKey);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _inFlight[cacheKey] = future;
    return future;
  }

  void prefetch(ItemDetailRequest request) {
    unawaited(
      load(request).then<void>(
        (ItemDetail _) {},
        onError: (Object error, StackTrace stackTrace) {},
      ),
    );
  }

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  Future<ItemDetail> _loadUncached(
    ItemDetailRequest request,
    String language,
  ) async {
    final Map<String, dynamic> payload = await _resolvedFunctionClient
        .invokeJson(
          Env.exploreFunction,
          body: <String, dynamic>{
            'action': 'getExploreItemDetail',
            'category': request.category.storageKey,
            'id': request.id,
            'language': language.isEmpty ? null : language,
          },
        );
    final Map<String, dynamic> item = _asMap(payload['item']);
    final List<String> images = _stringList(item['images'])
        .map(MediaUrlResolver.resolve)
        .where((String image) => image.isNotEmpty)
        .toList(growable: false);
    final String? rawCoverImage = _string(item['coverImage']);
    final String? coverImage = rawCoverImage == null
        ? (images.isNotEmpty ? images.first : null)
        : MediaUrlResolver.resolve(rawCoverImage);
    final List<String> galleryImages = _stringList(item['galleryImages'])
        .map(MediaUrlResolver.resolve)
        .where((String image) => image.isNotEmpty)
        .toList(growable: false);
    return ItemDetail(
      id: _string(item['id']) ?? request.id,
      reviewContentId: _string(item['reviewContentId']),
      name: _string(item['name']) ?? request.name,
      category: _category(item['category'], request.category),
      images: images,
      coverImage: coverImage,
      galleryImages: galleryImages,
      rating: _double(item['rating']) ?? 0,
      reviewCount: _integer(item['reviewCount']) ?? 0,
      ratingLabel: _string(item['ratingLabel']) ?? '',
      description: _string(item['description']) ?? '',
      whatToExpect: _string(item['whatToExpect']) ?? '',
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }
    throw const FormatException('Invalid Explore item detail response.');
  }

  String? _string(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map(_imageToken)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  String? _imageToken(Object? value) {
    final String? direct = _string(value);
    if (value is! Map) return direct;
    for (final String key in <String>[
      'url',
      'path',
      'key',
      'src',
      'image',
      'imagePath',
    ]) {
      final String? token = _string(value[key]);
      if (token != null) return token;
    }
    return null;
  }

  DetailCategory _category(Object? value, DetailCategory fallback) {
    switch (_string(value)?.toLowerCase()) {
      case 'activities':
      case 'activity':
        return DetailCategory.activities;
      case 'culture':
        return DetailCategory.culture;
      case 'food':
        return DetailCategory.food;
      case 'local_products':
      case 'local_product':
        return DetailCategory.localProducts;
      default:
        return fallback;
    }
  }
}

class _CachedItemDetail {
  _CachedItemDetail(this.detail) : cachedAt = DateTime.now();

  final ItemDetail detail;
  final DateTime cachedAt;
}
