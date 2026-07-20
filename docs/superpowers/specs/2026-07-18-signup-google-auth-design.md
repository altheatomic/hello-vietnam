# Signup Google Authentication Design

## Goal

Make the Google button on the signup screen start the same Supabase Google OAuth flow used by the login screen instead of displaying a message that tells the user to return to Login.

## Scope

- Change only the signup screen behavior and its focused widget tests.
- Keep the existing Google button layout and label.
- Disable signup actions while Google OAuth is being launched.
- Show a red, user-facing SnackBar if launching Google OAuth fails.
- Let the existing global router react to the authenticated Supabase session and route the user to onboarding or Home.
- Do not modify the Google provider configuration, `AuthRepository`, or routing rules.

## Testability

Allow `RegisterPage` to receive an optional Google sign-in callback. Production uses `AuthRepository.instance.signInWithGoogle`; widget tests inject a callback to verify the button starts authentication without initializing Supabase.

## Verification

- A widget test verifies tapping `Continue with Google` calls the injected OAuth callback and does not show the old Login-page instruction.
- A widget test verifies callback failures produce a red error SnackBar.
- Run focused tests, formatting, and Flutter static analysis.
