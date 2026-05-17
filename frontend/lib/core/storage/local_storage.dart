import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._();

  static final LocalStorage instance = LocalStorage._();

  SharedPreferences? _preferences;

  bool get isReady => _preferences != null;

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  String? getString(String key) => _preferences?.getString(key);

  Future<bool> setString(String key, String value) async {
    final SharedPreferences preferences = _ensureReady();
    return preferences.setString(key, value);
  }

  Future<bool> remove(String key) async {
    final SharedPreferences preferences = _ensureReady();
    return preferences.remove(key);
  }

  SharedPreferences _ensureReady() {
    final SharedPreferences? preferences = _preferences;
    if (preferences == null) {
      throw StateError(
        'LocalStorage is not initialized. Call initialize() before usage.',
      );
    }
    return preferences;
  }
}
