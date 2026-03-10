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

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
