import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController({NotificationRepository? repository})
    : _repository = repository ?? SupabaseNotificationRepository.instance;

  static final NotificationPreferencesController instance =
      NotificationPreferencesController();

  final NotificationRepository _repository;
  final Map<NotificationPreferenceType, NotificationPreference> _preferences =
      <NotificationPreferenceType, NotificationPreference>{};
  final Set<NotificationPreferenceType> _saving =
      <NotificationPreferenceType>{};

  bool _isLoading = false;
  bool _isLoaded = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get errorMessage => _errorMessage;

  NotificationPreference preference(NotificationPreferenceType type) =>
      _preferences[type] ?? _defaultPreference(type);

  bool isSaving(NotificationPreferenceType type) => _saving.contains(type);

  bool effectivePushEnabled(NotificationPreferenceType type) {
    final NotificationPreference value = preference(type);
    return value.effectivePushEnabled(
      preference(NotificationPreferenceType.all),
    );
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_isLoaded && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final List<NotificationPreference> values = await _repository
          .fetchPreferences();
      _preferences
        ..clear()
        ..addEntries(
          NotificationPreferenceType.values.map(
            (NotificationPreferenceType type) =>
                MapEntry(type, _defaultPreference(type)),
          ),
        );
      for (final NotificationPreference value in values) {
        _preferences[value.type] = value;
      }
      _isLoaded = true;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPushEnabled(
    NotificationPreferenceType type,
    bool enabled,
  ) async {
    if (_saving.contains(type)) return;
    final NotificationPreference previous = preference(type);
    final NotificationPreference next = previous.copyWith(pushEnabled: enabled);
    _preferences[type] = next;
    _saving.add(type);
    _errorMessage = null;
    notifyListeners();
    try {
      _preferences[type] = await _repository.updatePreference(next);
    } catch (error) {
      _preferences[type] = previous;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _saving.remove(type);
      notifyListeners();
    }
  }

  void reset() {
    _preferences.clear();
    _saving.clear();
    _isLoading = false;
    _isLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  NotificationPreference _defaultPreference(NotificationPreferenceType type) {
    return NotificationPreference(
      type: type,
      pushEnabled: true,
      inAppEnabled: true,
    );
  }
}
