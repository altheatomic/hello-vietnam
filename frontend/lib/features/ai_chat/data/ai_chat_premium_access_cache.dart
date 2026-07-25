import 'dart:async';

typedef AiChatPremiumStatusLoader = Future<bool> Function();
typedef AiChatClock = DateTime Function();

class AiChatPremiumAccessCache {
  AiChatPremiumAccessCache({
    this.ttl = const Duration(seconds: 30),
    AiChatClock? now,
  }) : _now = now ?? DateTime.now;

  static final AiChatPremiumAccessCache shared = AiChatPremiumAccessCache();

  final Duration ttl;
  final AiChatClock _now;
  final Map<String, _PremiumCacheEntry> _entries =
      <String, _PremiumCacheEntry>{};
  final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  Future<bool> load({
    required String userId,
    required AiChatPremiumStatusLoader loader,
    bool forceRefresh = false,
  }) {
    final String key = userId.trim();
    if (key.isEmpty) return Future<bool>.value(false);

    final DateTime now = _now();
    final _PremiumCacheEntry? cached = _entries[key];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.loadedAt) < ttl) {
      return Future<bool>.value(cached.isPremium);
    }

    final Future<bool>? pending = _inFlight[key];
    if (pending != null) return pending;

    final Future<bool> request = loader()
        .then((bool isPremium) {
          _entries[key] = _PremiumCacheEntry(
            isPremium: isPremium,
            loadedAt: _now(),
          );
          return isPremium;
        })
        .whenComplete(() {
          _inFlight.remove(key);
        });
    _inFlight[key] = request;
    return request;
  }

  void invalidate(String userId) {
    _entries.remove(userId.trim());
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }
}

class _PremiumCacheEntry {
  const _PremiumCacheEntry({required this.isPremium, required this.loadedAt});

  final bool isPremium;
  final DateTime loadedAt;
}
