# Login Credential Error Design

## Goal

Replace the technical Supabase authentication error shown by the user login screen with a clear, red notification when the submitted email or password is incorrect.

## Scope

- Apply only to the user login screen in `frontend/lib/features/auth/presentation/login_page.dart`.
- Keep the existing red `SnackBar` presentation.
- Show `Incorrect email or password` for rejected email/password credentials.
- Do not expose `AuthException`, `Auth message`, stack details, or `e.toString()` to the user.
- Preserve a separate generic message for non-credential authentication failures.
- Do not change the admin login screen, Google sign-in flow, field layout, or navigation.

## Error Flow

1. The user submits a non-empty email and password.
2. `AuthRepository.signIn` calls Supabase password authentication.
3. The login screen catches a typed `AuthException`.
4. A credential rejection is mapped to `Incorrect email or password`.
5. Other authentication failures are mapped to a generic sign-in failure message.
6. The selected message is displayed in the existing red `SnackBar`.

## Testing

Add focused tests for the error-message mapping before changing production behavior:

- Invalid-login credential errors map to `Incorrect email or password`.
- The displayed message contains no Supabase exception prefix or technical details.
- Unrelated authentication failures retain a generic user-facing message.

Run the focused test, the relevant Flutter test suite, formatting checks, and static analysis before completion.
