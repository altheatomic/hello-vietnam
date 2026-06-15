import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TravelPreferencesRepository extends ChangeNotifier {
  TravelPreferencesRepository._() {
    AuthRepository.instance.addListener(_handleAuthChanged);
  }

  static final TravelPreferencesRepository instance =
      TravelPreferencesRepository._();

  static const String _storageKeyPrefix = 'travel_preferences_v1_';
  static const String _functionName = 'travel-preferences';

  final SupabaseClient _client = Supabase.instance.client;

  bool _isReady = false;
  bool _isHydratingCurrentUser = false;
  UserTravelPreferences? _currentPreferences;

  bool get isReady => _isReady && !_isHydratingCurrentUser;

  String? get _currentUserId => AuthRepository.instance.user?.id;

  UserTravelPreferences? get currentPreferences {
    if (!_isReady || _currentUserId == null) {
      return null;
    }
    return _currentPreferences;
  }

  bool get hasCompletedCurrentUser => currentPreferences != null;

  Future<void> initialize() async {
    if (_isReady) {
      return;
    }
    await app_storage.LocalStorage.instance.initialize();
    _isReady = true;
    _currentPreferences = _readCachedCurrentUserPreferences();
    if (_currentUserId != null) {
      _isHydratingCurrentUser = true;
      await _refreshCurrentUserPreferences(notify: false);
      _isHydratingCurrentUser = false;
    }
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

    final Session? session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('Please sign in to save travel preferences.');
    }

    final FunctionResponse response = await _client.functions.invoke(
      _functionName,
      headers: <String, String>{
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: <String, dynamic>{
        'action': 'saveTravelPreferences',
        'preferences': preferences.toJson(),
      },
    );

    final Map<String, dynamic>? data = _asJsonMap(response.data);
    final Object? errorValue = data?['error'];
    if (errorValue != null) {
      throw StateError(errorValue.toString());
    }

    final UserTravelPreferences savedPreferences =
        _parsePreferences(data?['preferences']) ?? preferences;
    await _setCachedCurrentUserPreferences(
      userId,
      savedPreferences,
      notify: notify,
    );
  }

  Future<void> clearCurrentUserPreferences() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      return;
    }
    final Session? session = _client.auth.currentSession;
    if (session != null) {
      final FunctionResponse response = await _client.functions.invoke(
        _functionName,
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: const <String, dynamic>{'action': 'clearTravelPreferences'},
      );
      final Map<String, dynamic>? data = _asJsonMap(response.data);
      final Object? errorValue = data?['error'];
      if (errorValue != null) {
        throw StateError(errorValue.toString());
      }
    }

    await _setCachedCurrentUserPreferences(userId, null);
  }

  String _storageKeyFor(String userId) => '$_storageKeyPrefix$userId';

  void refresh() {
    if (_isReady) {
      unawaited(_refreshCurrentUserPreferences());
    }
  }

  void _handleAuthChanged() {
    if (!_isReady) return;

    _isHydratingCurrentUser = _currentUserId != null;
    _currentPreferences = _readCachedCurrentUserPreferences();
    notifyListeners();
    unawaited(_refreshAfterAuthChange());
  }

  Future<void> _refreshAfterAuthChange() async {
    try {
      await _refreshCurrentUserPreferences();
    } finally {
      _isHydratingCurrentUser = false;
      if (_isReady) {
        notifyListeners();
      }
    }
  }

  Future<void> _refreshCurrentUserPreferences({bool notify = true}) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _currentPreferences = null;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    final Session? session = _client.auth.currentSession;
    if (session == null) {
      _currentPreferences = _readCachedCurrentUserPreferences();
      if (notify) {
        notifyListeners();
      }
      return;
    }

    try {
      final FunctionResponse response = await _client.functions.invoke(
        _functionName,
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: const <String, dynamic>{'action': 'getTravelPreferences'},
      );

      final Map<String, dynamic>? data = _asJsonMap(response.data);
      final Object? errorValue = data?['error'];
      if (errorValue != null) {
        throw StateError(errorValue.toString());
      }

      final UserTravelPreferences? remotePreferences = _parsePreferences(
        data?['preferences'],
      );
      await _setCachedCurrentUserPreferences(
        userId,
        remotePreferences,
        notify: notify,
      );
    } catch (_) {
      _currentPreferences = _readCachedCurrentUserPreferences();
      if (notify) {
        notifyListeners();
      }
    }
  }

  UserTravelPreferences? _readCachedCurrentUserPreferences() {
    final String? userId = _currentUserId;
    if (!_isReady || userId == null) {
      return null;
    }

    final String? raw = app_storage.LocalStorage.instance.getString(
      _storageKeyFor(userId),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return UserTravelPreferences.fromStorageValue(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setCachedCurrentUserPreferences(
    String userId,
    UserTravelPreferences? preferences, {
    bool notify = true,
  }) async {
    if (preferences == null) {
      await app_storage.LocalStorage.instance.remove(_storageKeyFor(userId));
    } else {
      await app_storage.LocalStorage.instance.setString(
        _storageKeyFor(userId),
        preferences.toStorageValue(),
      );
    }

    _currentPreferences = preferences;
    if (notify) {
      notifyListeners();
    }
  }

  UserTravelPreferences? _parsePreferences(dynamic value) {
    final Map<String, dynamic>? json = _asJsonMap(value);
    if (json == null) {
      return null;
    }

    try {
      return UserTravelPreferences.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic innerValue) =>
            MapEntry(key.toString(), innerValue),
      );
    }
    return null;
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_handleAuthChanged);
    super.dispose();
  }
}
