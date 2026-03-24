import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository extends ChangeNotifier {
  // Singleton
  static final AuthRepository instance = AuthRepository._();

  AuthRepository._() {
    _user = _supabase.auth.currentUser;
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
  String? get currentUserEmail => (_user ?? _supabase.auth.currentUser)?.email;

  Future<String?> getCurrentUserFullName() async {
    final currentUser = _user ?? _supabase.auth.currentUser;
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      final response =
          await _supabase
              .from('user_account')
              .select('full_name')
              .eq('id_user', userId)
              .maybeSingle();

      final dbFullName = (response?['full_name'] as String?)?.trim();
      if (dbFullName != null && dbFullName.isNotEmpty) {
        return dbFullName;
      }
    } catch (e) {
      debugPrint('Load full name error: $e');
    }

    final metadataFullName =
        (currentUser?.userMetadata?['full_name'] as String?)?.trim();
    if (metadataFullName != null && metadataFullName.isNotEmpty) {
      return metadataFullName;
    }

    return null;
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // Handle error
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            kIsWeb ? null : 'com.example.hellovietnam://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      debugPrint(e.message);
      rethrow;
    }
  }

  Future<void> signUp(
      {required String name,
      required String email,
      required String password}) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
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
      rethrow;
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
