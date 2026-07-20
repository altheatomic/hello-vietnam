import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/auth/presentation/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps invalid login credentials to a safe user-facing message', () {
    final message = loginErrorMessage(
      const AuthException('Invalid login credentials'),
    );

    expect(message, 'Incorrect email or password');
    expect(message, isNot(contains('AuthException')));
  });

  test('maps unrelated authentication failures to a generic message', () {
    final message = loginErrorMessage(
      const AuthException('Network request failed'),
    );

    expect(message, 'Failed to sign in. Please try again.');
    expect(message, isNot(contains('Network request failed')));
  });

  test('maps unknown failures to a generic message', () {
    expect(
      loginErrorMessage(Exception('internal details')),
      'Failed to sign in. Please try again.',
    );
  });
}
