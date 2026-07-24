import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/loyalty/data/loyalty_award_service.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

class WishlistController extends ChangeNotifier {
  WishlistController._();

  static final WishlistController instance = WishlistController._();

  final WishlistRepository _repository = WishlistRepository();
  final Set<String> _favoriteKeys = <String>{};
  List<WishlistRepositoryItem> _items = const <WishlistRepositoryItem>[];
  bool _isLoaded = false;
  Future<void>? _loadFuture;

  bool get isLoaded => _isLoaded;
  List<WishlistRepositoryItem> get items =>
      List<WishlistRepositoryItem>.unmodifiable(_items);

  bool isFavorite({required FavoriteType type, required String rawItemId}) {
    return _favoriteKeys.contains(_key(type, rawItemId));
  }

  Future<void> ensureLoaded({bool force = false}) {
    if (!force && _isLoaded) return Future<void>.value();
    final Future<void>? currentLoad = _loadFuture;
    if (!force && currentLoad != null) return currentLoad;

    final Future<void> nextLoad = _load();
    _loadFuture = nextLoad;
    return nextLoad.whenComplete(() {
      if (_loadFuture == nextLoad) {
        _loadFuture = null;
      }
    });
  }

  Future<void> refresh() => ensureLoaded(force: true);

  Future<bool?> toggleFavorite({
    required FavoriteType type,
    required String rawItemId,
    String? fallbackName,
  }) async {
    if (AuthRepository.instance.user == null) {
      return null;
    }

    final String key = _key(type, rawItemId);
    final bool previous = _favoriteKeys.contains(key);
    _setLocalFavorite(key, !previous);

    try {
      final bool isFavorite = await _repository.toggleFavoriteByRawId(
        type: type,
        rawItemId: rawItemId,
        fallbackName: fallbackName,
      );
      _setLocalFavorite(key, isFavorite);
      _updateLocalWishlistItem(
        type: type,
        itemId: rawItemId,
        isFavorite: isFavorite,
        fallbackName: fallbackName,
      );
      if (isFavorite && !previous) {
        unawaited(
          _awardWishlistPoints(
            type: type,
            itemId: rawItemId,
            fallbackName: fallbackName,
          ),
        );
      }
      return isFavorite;
    } catch (_) {
      _setLocalFavorite(key, previous);
      rethrow;
    }
  }

  Future<void> setFavorite({
    required FavoriteType type,
    required String itemId,
    required bool isFavorite,
  }) async {
    if (AuthRepository.instance.user == null) {
      return;
    }

    final String key = _key(type, itemId);
    final bool previous = _favoriteKeys.contains(key);
    _setLocalFavorite(key, isFavorite);

    try {
      await _repository.setFavorite(
        itemId: itemId,
        type: type,
        isFavorite: isFavorite,
      );
      _updateLocalWishlistItem(
        type: type,
        itemId: itemId,
        isFavorite: isFavorite,
      );
      if (isFavorite && !previous) {
        unawaited(_awardWishlistPoints(type: type, itemId: itemId));
      }
    } catch (_) {
      _setLocalFavorite(key, previous);
      rethrow;
    }
  }

  Future<void> _load() async {
    if (AuthRepository.instance.user == null) {
      _favoriteKeys.clear();
      _items = const <WishlistRepositoryItem>[];
      _isLoaded = true;
      notifyListeners();
      return;
    }

    try {
      final List<WishlistRepositoryItem> items = await _repository
          .fetchWishlist(language: AppLanguageController.instance.languageCode);
      _items = items;
      _favoriteKeys
        ..clear()
        ..addAll(
          items.map((WishlistRepositoryItem item) => _key(item.type, item.id)),
        );
    } catch (_) {
      // Keep the current local state when the remote wishlist cannot be read.
    }
    _isLoaded = true;
    notifyListeners();
  }

  void _setLocalFavorite(String key, bool isFavorite) {
    if (isFavorite) {
      _favoriteKeys.add(key);
    } else {
      _favoriteKeys.remove(key);
    }
    _isLoaded = true;
    notifyListeners();
  }

  void _updateLocalWishlistItem({
    required FavoriteType type,
    required String itemId,
    required bool isFavorite,
    String? fallbackName,
  }) {
    final String normalizedId = itemId.trim();
    if (normalizedId.isEmpty) return;

    final int index = _items.indexWhere(
      (WishlistRepositoryItem item) =>
          item.type == type && item.id == normalizedId,
    );
    if (!isFavorite) {
      if (index < 0) return;
      final next = List<WishlistRepositoryItem>.of(_items)..removeAt(index);
      _items = List<WishlistRepositoryItem>.unmodifiable(next);
      notifyListeners();
      return;
    }

    if (index >= 0) return;
    final String title = fallbackName?.trim().isNotEmpty == true
        ? fallbackName!.trim()
        : _fallbackTitleForType(type);
    _items = List<WishlistRepositoryItem>.unmodifiable(<WishlistRepositoryItem>[
      WishlistRepositoryItem(
        id: normalizedId,
        type: type,
        title: title,
        description: '',
      ),
      ..._items,
    ]);
    notifyListeners();
  }

  String _fallbackTitleForType(FavoriteType type) {
    switch (type) {
      case FavoriteType.city:
        return 'Saved city';
      case FavoriteType.place:
        return 'Saved place';
      case FavoriteType.food:
        return 'Saved food';
      case FavoriteType.culture:
        return 'Saved culture';
      case FavoriteType.activity:
        return 'Saved activity';
      case FavoriteType.localProduct:
        return 'Saved local product';
    }
  }

  String _key(FavoriteType type, String rawItemId) {
    return '${type.dbValue}:${rawItemId.trim()}';
  }

  Future<void> _awardWishlistPoints({
    required FavoriteType type,
    required String itemId,
    String? fallbackName,
  }) async {
    await LoyaltyAwardService.instance.award(
      actionType: 'wishlist_add',
      referenceTable: 'wishlist',
      description: 'Added item to wishlist',
      metadata: <String, dynamic>{
        'favorite_type': type.dbValue,
        'item_id': itemId.trim(),
        if (fallbackName?.trim().isNotEmpty == true)
          'name': fallbackName!.trim(),
      },
    );
  }
}
