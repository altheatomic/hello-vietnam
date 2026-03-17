import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository extends ChangeNotifier {
  // Singleton
  static final AuthRepository instance = AuthRepository._();

  AuthRepository._() {
    _authSubscription =
        _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  final _supabase = Supabase.instance.client;
  User? _user;
  late final StreamSubscription<AuthState> _authSubscription;


  User? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // Handle error
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> signUp(
      {required String name,
      required String email,
      required String password}) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user != null) {
        await _supabase.from('user_account').insert({
          'id_user': user.id,
          'full_name': name,
          'username': email,
        });
      }
    } on AuthException catch (e) {
      // Handle error
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'com.example.hellovietnam://reset-password',
      );
    } on AuthException catch (e) {
      debugPrint('Reset password error: ${e.message}');

      // Create more specific error messages
      if (e.message.contains('rate limit') || e.message.contains('Rate limit')) {
        throw Exception('RATE_LIMIT: Too many reset emails sent. Please wait 1 hour before trying again.');
      } else if (e.message.contains('Invalid email')) {
        throw Exception('INVALID_EMAIL: Please enter a valid email address.');
      } else {
        throw Exception('RESET_FAILED: ${e.message}');
      }
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      debugPrint('Update password error: ${e.message}');
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
