import 'package:flutter/foundation.dart';

import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

class WishlistController extends ChangeNotifier {
  WishlistController._();

  static final WishlistController instance = WishlistController._();

  final WishlistRepository _repository = WishlistRepository();
  final Set<String> _favoriteKeys = <String>{};
  bool _isLoaded = false;
  Future<void>? _loadFuture;

  bool get isLoaded => _isLoaded;

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
      await refresh();
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
      await refresh();
    } catch (_) {
      _setLocalFavorite(key, previous);
      rethrow;
    }
  }

  Future<void> _load() async {
    if (AuthRepository.instance.user == null) {
      _favoriteKeys.clear();
      _isLoaded = true;
      notifyListeners();
      return;
    }

    try {
      final List<WishlistRepositoryItem> items = await _repository
          .fetchWishlist();
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

  String _key(FavoriteType type, String rawItemId) {
    return '${type.dbValue}:${rawItemId.trim()}';
  }
}
