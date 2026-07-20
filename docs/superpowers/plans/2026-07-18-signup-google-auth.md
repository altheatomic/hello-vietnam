# Signup Google Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the signup screen's Google button launch Supabase Google OAuth directly.

**Architecture:** Keep OAuth logic in `AuthRepository` and inject an optional callback into `RegisterPage` for isolated widget testing. The existing router observes `AuthRepository` and performs post-auth navigation.

**Tech Stack:** Flutter, Dart, Supabase Auth, flutter_test.

## Global Constraints

- Keep the current Google button layout and label.
- Remove the instruction that Google sign-in must be performed from Login.
- Disable signup actions while OAuth starts.
- Show a red SnackBar when OAuth launch fails.
- Do not change provider configuration, repository behavior, or router rules.

---

### Task 1: Reproduce the signup Google-button bug

**Files:**
- Create: `frontend/test/features/auth/presentation/register_page_test.dart`
- Modify: `frontend/lib/features/auth/presentation/register_page.dart`

**Interfaces:**
- Produce `RegisterPage({Key? key, Future<void> Function()? googleSignIn})`.
- Production fallback: `AuthRepository.instance.signInWithGoogle`.

- [ ] **Step 1: Write a widget test that injects a callback and taps `Continue with Google`**

```dart
testWidgets('Google button starts OAuth from the signup screen', (tester) async {
  var calls = 0;
  await tester.pumpWidget(MaterialApp(
    home: RegisterPage(googleSignIn: () async => calls++),
  ));
  await tester.ensureVisible(find.text('Continue with Google'));
  await tester.tap(find.text('Continue with Google'));
  await tester.pump();
  expect(calls, 1);
  expect(find.text('Google Sign-In is handled in Login page'), findsNothing);
});
```

- [ ] **Step 2: Run the test and verify it fails because `googleSignIn` is not accepted**

Run: `flutter test test/features/auth/presentation/register_page_test.dart`

Expected: compilation failure for the missing named parameter.

### Task 2: Start OAuth and handle failures

**Files:**
- Modify: `frontend/lib/features/auth/presentation/register_page.dart`
- Test: `frontend/test/features/auth/presentation/register_page_test.dart`

- [ ] **Step 1: Add the optional callback and async handler**

```dart
final Future<void> Function()? googleSignIn;

Future<void> _onGoogleSignIn() async {
  setState(() => _isLoading = true);
  try {
    await (widget.googleSignIn ?? AuthRepository.instance.signInWithGoogle)();
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.ui('Google sign in failed')),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

- [ ] **Step 2: Disable the Google button while `_isLoading`**

```dart
onPressed: _isLoading ? null : _onGoogleSignIn,
```

- [ ] **Step 3: Add a failure test that expects the generic red SnackBar**

Run: `flutter test test/features/auth/presentation/register_page_test.dart`

Expected: both widget tests pass.

### Task 3: Verify and reload

**Files:**
- No additional files.

- [ ] **Step 1:** Run `dart format` on the changed Dart files.
- [ ] **Step 2:** Run the focused widget test.
- [ ] **Step 3:** Run `flutter analyze`.
- [ ] **Step 4:** Hot reload the running Android app and confirm Flutter reports a successful reload.
