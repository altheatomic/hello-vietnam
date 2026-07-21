# Login Credential Error Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show `Incorrect email or password` in the existing red user-login SnackBar for rejected credentials without exposing Supabase technical errors.

**Architecture:** Add a small pure error-message mapper next to the login presentation code. The login catch block uses the mapper for typed Supabase authentication errors and falls back to a generic sign-in message for unrelated failures. Keep repository behavior, admin login, Google login, layout, and routing unchanged.

**Tech Stack:** Flutter, Dart, `supabase_flutter`, `flutter_test`.

## Global Constraints

- Apply only to the user login screen.
- Keep the existing red SnackBar.
- Never show `AuthException`, `Auth message`, stack details, or raw `e.toString()` to the user.
- Preserve a generic message for non-credential failures.

### Task 1: Add failing mapper tests

**Files:**
- Create: `frontend/test/features/auth/presentation/login_error_message_test.dart`

**Interfaces:**
- Test the pure function `loginErrorMessage(Object error)` exposed from `login_page.dart`.

- [ ] **Step 1: Write tests for credential and fallback mappings**

```dart
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
```

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run: `flutter test test/features/auth/presentation/login_error_message_test.dart`

Expected: FAIL because `loginErrorMessage` does not exist yet.

### Task 2: Implement safe mapping and wire the SnackBar

**Files:**
- Modify: `frontend/lib/features/auth/presentation/login_page.dart`

**Interfaces:**
- Produce `String loginErrorMessage(Object error)` for the focused tests and the login catch block.

- [ ] **Step 1: Add the minimal pure mapper**

```dart
String loginErrorMessage(Object error) {
  if (error is AuthException &&
      error.message.toLowerCase().contains('invalid login credentials')) {
    return 'Incorrect email or password';
  }
  return 'Failed to sign in. Please try again.';
}
```

- [ ] **Step 2: Replace raw exception interpolation in `_onContinue`**

```dart
content: Text(loginErrorMessage(e)),
```

- [ ] **Step 3: Run the focused tests and formatter**

Run: `dart format lib/features/auth/presentation/login_page.dart test/features/auth/presentation/login_error_message_test.dart`

Run: `flutter test test/features/auth/presentation/login_error_message_test.dart`

Expected: formatter succeeds and all focused tests pass.

### Task 3: Verify regression safety

**Files:**
- No additional files.

- [ ] **Step 1: Run the complete Flutter test suite**

Run: `flutter test`

Expected: exit code 0 with no test failures.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

Expected: no new errors attributable to this change.

- [ ] **Step 3: Inspect the final diff**

Run: `git diff -- frontend/lib/features/auth/presentation/login_page.dart frontend/test/features/auth/presentation/login_error_message_test.dart`

Expected: only the safe mapper, SnackBar wiring, and focused tests are changed; unrelated user worktree changes remain untouched.
