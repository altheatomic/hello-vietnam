import 'package:flutter/foundation.dart';

/// Simple auth state manager.
/// Tracks whether the user is currently logged in.
/// Will be replaced with real auth logic later.
class AuthState extends ChangeNotifier {
  // Singleton
  static final AuthState instance = AuthState._();
  AuthState._();

  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
