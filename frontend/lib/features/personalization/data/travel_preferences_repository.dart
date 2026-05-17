import 'package:flutter/foundation.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';

class TravelPreferencesRepository extends ChangeNotifier {
  TravelPreferencesRepository._() {
    AuthRepository.instance.addListener(_handleAuthChanged);
  }

  static final TravelPreferencesRepository instance =
      TravelPreferencesRepository._();

  static const String _storageKeyPrefix = 'travel_preferences_v1_';

  bool _isReady = false;

  bool get isReady => _isReady;

  String? get _currentUserId => AuthRepository.instance.user?.id;

  UserTravelPreferences? get currentPreferences {
    final String? userId = _currentUserId;
    if (!_isReady || userId == null) {
      return null;
    }

    final String? raw = LocalStorage.instance.getString(_storageKeyFor(userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return UserTravelPreferences.fromStorageValue(raw);
    } catch (_) {
      return null;
    }
  }

  bool get hasCompletedCurrentUser => currentPreferences != null;

  Future<void> initialize() async {
    if (_isReady) {
      return;
    }
    await LocalStorage.instance.initialize();
    _isReady = true;
    notifyListeners();
  }

  Future<void> saveCurrentUserPreferences(
    UserTravelPreferences preferences, {
    bool notify = true,
  }) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      return;
    }
    await LocalStorage.instance.setString(
      _storageKeyFor(userId),
      preferences.toStorageValue(),
    );
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> clearCurrentUserPreferences() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      return;
    }
    await LocalStorage.instance.remove(_storageKeyFor(userId));
    notifyListeners();
  }

  String _storageKeyFor(String userId) => '$_storageKeyPrefix$userId';

  void refresh() {
    if (_isReady) {
      notifyListeners();
    }
  }

  void _handleAuthChanged() {
    if (_isReady) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_handleAuthChanged);
    super.dispose();
  }
}
