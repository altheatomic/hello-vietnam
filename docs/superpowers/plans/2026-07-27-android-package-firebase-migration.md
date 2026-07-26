# Android Package and Firebase Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `com.hellovietnam.app` the single production identity for the Hello Vietnam Android app, its Firebase client, and every Android callback path.

**Architecture:** Register a second Android app in the existing Firebase project and preserve the old registration as rollback. Centralize the Android identity used by Dart, migrate native Android configuration and callbacks in a coordinated change, then validate Firebase, Flutter, Gradle, Supabase redirects, and the built artifact independently.

**Tech Stack:** Flutter/Dart, Android Gradle Kotlin DSL, Kotlin, Firebase Core and Messaging, Supabase Auth, Stripe checkout callbacks, PowerShell, Flutter Test

## Global Constraints

- The final Android application ID is exactly `com.hellovietnam.app`.
- Firebase project ID remains exactly `hello-vietnam-26078`.
- Register a new Firebase Android app; do not edit or delete the existing `com.example.hellovietnam` app.
- Keep `frontend/android/app/google-services.json` ignored and uncommitted.
- Keep the iOS project unchanged.
- Preserve all unrelated user changes already present in the working tree.
- Do not remove unrelated Supabase Auth redirect URLs.
- Do not claim a successful Android build if Java or the Android SDK is unavailable.

---

## File Structure

**Create**

- `frontend/lib/core/config/app_identity.dart`: the single Dart source of truth for the Android package and callback URLs.
- `frontend/test/core/config/app_identity_test.dart`: guards the production package and callback constants.
- `frontend/test/app/deep_link_state_test.dart`: verifies the new payment callback scheme and rejection of the old scheme.
- `frontend/lib/features/profile/domain/subscription_checkout_urls.dart`: pure builder for web and Android Stripe return URLs.
- `frontend/test/features/profile/domain/subscription_checkout_urls_test.dart`: verifies exact Android intent URLs and unchanged web URLs.

**Move and modify**

- `frontend/android/app/src/main/kotlin/com/example/hellovietnam/MainActivity.kt`
  to `frontend/android/app/src/main/kotlin/com/hellovietnam/app/MainActivity.kt`:
  align the Kotlin package with the Android namespace.

**Modify**

- `frontend/android/app/build.gradle.kts`: set namespace and application ID.
- `frontend/android/app/src/main/AndroidManifest.xml`: accept the new custom URL scheme.
- `frontend/android/app/google-services.json`: install generated configuration for the new Firebase Android app; ignored, never staged.
- `frontend/lib/app/deep_link_state.dart`: recognize the centralized scheme.
- `frontend/lib/core/auth/auth_repository.dart`: use centralized OAuth and reset-password callback URLs.
- `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`: delegate checkout return URL construction to the pure helper.
- `frontend/lib/features/planner/presentation/trip_map_page.dart`: use the production package as OpenStreetMap user agent.
- `frontend/test/features/profile/data/subscription_repository_test.dart`: use the new callback scheme in the repository contract example.
- `backend/supabase/functions/ai-chat/ai_chat_domain_test.ts`: keep the sanitized deep-link example aligned with the production package.
- `backend/supabase/functions/notifications/README.md`: document the new Firebase Android package.
- `huongdan.md`: document the new Firebase Android package.

**External state**

- Firebase project `hello-vietnam-26078`: add an Android app with package `com.hellovietnam.app`.
- Supabase Auth redirect allowlist: add the login and reset-password callbacks without removing existing URLs.
- Google Play Console: use an app entry associated with `com.hellovietnam.app` for the eventual release.

---

### Task 1: Centralize the Dart Android Identity and Deep-Link Contract

**Files:**

- Create: `frontend/lib/core/config/app_identity.dart`
- Create: `frontend/test/core/config/app_identity_test.dart`
- Create: `frontend/test/app/deep_link_state_test.dart`
- Modify: `frontend/lib/app/deep_link_state.dart:43-48`

**Interfaces:**

- Produces: `AppIdentity.androidApplicationId`, `AppIdentity.androidUrlScheme`, `AppIdentity.loginCallbackUrl`, and `AppIdentity.resetPasswordCallbackUrl`, all compile-time `String` constants.
- Consumes: `appRouteLocationFromDeepLink(Uri uri)` from `deep_link_state.dart`.

- [ ] **Step 1: Write the failing identity tests**

Create `frontend/test/core/config/app_identity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/app_identity.dart';

void main() {
  test('Android production identity stays synchronized', () {
    expect(AppIdentity.androidApplicationId, 'com.hellovietnam.app');
    expect(AppIdentity.androidUrlScheme, AppIdentity.androidApplicationId);
    expect(
      AppIdentity.loginCallbackUrl,
      'com.hellovietnam.app://login-callback',
    );
    expect(
      AppIdentity.resetPasswordCallbackUrl,
      'com.hellovietnam.app://reset-password',
    );
  });
}
```

Create `frontend/test/app/deep_link_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/deep_link_state.dart';

void main() {
  group('appRouteLocationFromDeepLink', () {
    test('maps the production Android payment callback to the app route', () {
      final Uri uri = Uri.parse(
        'com.hellovietnam.app://upgrade-payment'
        '?plan=6m&stripe_session_id=cs_test_123',
      );

      expect(
        appRouteLocationFromDeepLink(uri),
        '/upgrade-payment?plan=6m&stripe_session_id=cs_test_123',
      );
    });

    test('rejects the retired example-package callback', () {
      final Uri uri = Uri.parse(
        'com.example.hellovietnam://upgrade-payment?plan=6m',
      );

      expect(appRouteLocationFromDeepLink(uri), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify the new contract fails**

Run from `frontend`:

```powershell
flutter test test/core/config/app_identity_test.dart test/app/deep_link_state_test.dart
```

Expected: FAIL because `app_identity.dart` does not exist and the current router only accepts `com.example.hellovietnam`.

- [ ] **Step 3: Add the production identity constants**

Create `frontend/lib/core/config/app_identity.dart`:

```dart
abstract final class AppIdentity {
  static const String androidApplicationId = 'com.hellovietnam.app';
  static const String androidUrlScheme = androidApplicationId;
  static const String loginCallbackUrl =
      '$androidUrlScheme://login-callback';
  static const String resetPasswordCallbackUrl =
      '$androidUrlScheme://reset-password';
}
```

Update `frontend/lib/app/deep_link_state.dart`:

```dart
import '../core/config/app_identity.dart';
```

Replace the hard-coded scheme comparison with:

```dart
final bool isAppLink = uri.scheme == AppIdentity.androidUrlScheme;
```

- [ ] **Step 4: Format and run the focused tests**

Run from `frontend`:

```powershell
dart format lib/core/config/app_identity.dart lib/app/deep_link_state.dart test/core/config/app_identity_test.dart test/app/deep_link_state_test.dart
flutter test test/core/config/app_identity_test.dart test/app/deep_link_state_test.dart
```

Expected: both test files PASS.

- [ ] **Step 5: Commit the identity contract**

```powershell
git add -- frontend/lib/core/config/app_identity.dart frontend/lib/app/deep_link_state.dart frontend/test/core/config/app_identity_test.dart frontend/test/app/deep_link_state_test.dart
git commit -m "refactor: centralize Android app identity"
```

---

### Task 2: Migrate Authentication, Payment, and Map Callbacks

**Files:**

- Create: `frontend/lib/features/profile/domain/subscription_checkout_urls.dart`
- Create: `frontend/test/features/profile/domain/subscription_checkout_urls_test.dart`
- Modify: `frontend/lib/core/auth/auth_repository.dart:214-224,303-308`
- Modify: `frontend/lib/features/profile/presentation/upgrade_payment_page.dart:1534-1548`
- Modify: `frontend/lib/features/planner/presentation/trip_map_page.dart:207-213`
- Modify: `frontend/test/features/profile/data/subscription_repository_test.dart:58-75`

**Interfaces:**

- Consumes: constants from `AppIdentity`.
- Produces: `subscriptionCheckoutReturnUrl(String planCode, {required bool success, required bool isWeb, required String webOrigin}) -> String`.

- [ ] **Step 1: Write failing checkout URL tests**

Create `frontend/test/features/profile/domain/subscription_checkout_urls_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/profile/domain/subscription_checkout_urls.dart';

void main() {
  group('subscriptionCheckoutReturnUrl', () {
    test('builds the Android success intent with the production package', () {
      expect(
        subscriptionCheckoutReturnUrl(
          '6m',
          success: true,
          isWeb: false,
          webOrigin: '',
        ),
        'intent://upgrade-payment?plan=6m'
        '&stripe_session_id={CHECKOUT_SESSION_ID}'
        '#Intent;scheme=com.hellovietnam.app;'
        'package=com.hellovietnam.app;end',
      );
    });

    test('builds the Android cancellation intent with the production package', () {
      expect(
        subscriptionCheckoutReturnUrl(
          '12m',
          success: false,
          isWeb: false,
          webOrigin: '',
        ),
        'intent://upgrade-payment?plan=12m&stripe_cancelled=1'
        '#Intent;scheme=com.hellovietnam.app;'
        'package=com.hellovietnam.app;end',
      );
    });

    test('keeps the web success callback unchanged', () {
      expect(
        subscriptionCheckoutReturnUrl(
          '6m',
          success: true,
          isWeb: true,
          webOrigin: 'https://hello-vietnam.test',
        ),
        'https://hello-vietnam.test/#/upgrade-payment'
        '?plan=6m&stripe_session_id={CHECKOUT_SESSION_ID}',
      );
    });
  });
}
```

- [ ] **Step 2: Run the checkout URL test to verify it fails**

Run from `frontend`:

```powershell
flutter test test/features/profile/domain/subscription_checkout_urls_test.dart
```

Expected: FAIL because `subscription_checkout_urls.dart` does not exist.

- [ ] **Step 3: Implement the pure checkout URL builder**

Create `frontend/lib/features/profile/domain/subscription_checkout_urls.dart`:

```dart
import '../../../core/config/app_identity.dart';

String subscriptionCheckoutReturnUrl(
  String planCode, {
  required bool success,
  required bool isWeb,
  required String webOrigin,
}) {
  final String encodedPlan = Uri.encodeComponent(planCode);
  if (!isWeb) {
    if (success) {
      return 'intent://upgrade-payment?plan=$encodedPlan'
          '&stripe_session_id={CHECKOUT_SESSION_ID}'
          '#Intent;scheme=${AppIdentity.androidUrlScheme};'
          'package=${AppIdentity.androidApplicationId};end';
    }
    return 'intent://upgrade-payment?plan=$encodedPlan&stripe_cancelled=1'
        '#Intent;scheme=${AppIdentity.androidUrlScheme};'
        'package=${AppIdentity.androidApplicationId};end';
  }

  if (success) {
    return '$webOrigin/#/upgrade-payment?plan=$encodedPlan'
        '&stripe_session_id={CHECKOUT_SESSION_ID}';
  }
  return '$webOrigin/#/upgrade-payment?plan=$encodedPlan&stripe_cancelled=1';
}
```

Import the helper into `upgrade_payment_page.dart`, then replace the private
method body with:

```dart
return subscriptionCheckoutReturnUrl(
  planCode,
  success: success,
  isWeb: kIsWeb,
  webOrigin: Uri.base.origin,
);
```

- [ ] **Step 4: Replace remaining runtime Dart package strings**

Import `AppIdentity` into `auth_repository.dart` and use:

```dart
final String redirectTo = kIsWeb
    ? Uri.base.origin
    : AppIdentity.loginCallbackUrl;
```

and:

```dart
redirectTo: kIsWeb ? null : AppIdentity.resetPasswordCallbackUrl,
```

Import `AppIdentity` into `trip_map_page.dart` and use:

```dart
userAgentPackageName: AppIdentity.androidApplicationId,
```

Update the two input URLs and the two expected payload URLs in
`subscription_repository_test.dart` to
`com.hellovietnam.app://upgrade-payment?plan=6m`.

- [ ] **Step 5: Format and run focused Flutter tests**

Run from `frontend`:

```powershell
dart format lib/core/auth/auth_repository.dart lib/features/profile/domain/subscription_checkout_urls.dart lib/features/profile/presentation/upgrade_payment_page.dart lib/features/planner/presentation/trip_map_page.dart test/features/profile/domain/subscription_checkout_urls_test.dart test/features/profile/data/subscription_repository_test.dart
flutter test test/features/profile/domain/subscription_checkout_urls_test.dart test/features/profile/data/subscription_repository_test.dart test/app/deep_link_state_test.dart
```

Expected: all focused tests PASS.

- [ ] **Step 6: Confirm runtime Dart has no old package**

Run from the repository root:

```powershell
$matches = rg -n 'com\.example\.hellovietnam' frontend/lib
if ($LASTEXITCODE -eq 0) { $matches; throw 'Old package remains in frontend/lib' }
```

Expected: no output and exit without throwing.

- [ ] **Step 7: Commit callback migration**

```powershell
git add -- frontend/lib/core/auth/auth_repository.dart frontend/lib/features/profile/domain/subscription_checkout_urls.dart frontend/lib/features/profile/presentation/upgrade_payment_page.dart frontend/lib/features/planner/presentation/trip_map_page.dart frontend/test/features/profile/domain/subscription_checkout_urls_test.dart frontend/test/features/profile/data/subscription_repository_test.dart
git commit -m "fix: migrate Android callback URLs"
```

---

### Task 3: Register the Firebase App and Migrate Native Android Identity

**Files:**

- Modify: `frontend/android/app/build.gradle.kts:13,29`
- Modify: `frontend/android/app/src/main/AndroidManifest.xml:38`
- Move: `frontend/android/app/src/main/kotlin/com/example/hellovietnam/MainActivity.kt`
  to `frontend/android/app/src/main/kotlin/com/hellovietnam/app/MainActivity.kt`
- Modify ignored local file: `frontend/android/app/google-services.json`

**Interfaces:**

- Consumes: Firebase project `hello-vietnam-26078`.
- Produces: one active Firebase Android app and one local SDK config matching `com.hellovietnam.app`.

- [ ] **Step 1: Verify Firebase project and existing apps**

Set the Firebase tool environment to project `hello-vietnam-26078` and project
directory `D:\Work\hello-vietnam`. List Android apps.

Expected before creation: the list contains `com.example.hellovietnam`. If it
already contains `com.hellovietnam.app`, record its app ID and skip creation.

- [ ] **Step 2: Create the new Firebase Android app when absent**

Call the Firebase app creation operation with:

```json
{
  "platform": "android",
  "display_name": "HelloVietnam Android Production",
  "android_config": {
    "package_name": "com.hellovietnam.app"
  }
}
```

Expected: Firebase returns a new Android app ID in project
`hello-vietnam-26078`.

Keep the existing Supabase `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and
`FIREBASE_PRIVATE_KEY` secrets unchanged. They authenticate FCM HTTP v1 at the
Firebase project level. The newly packaged Android installation will obtain a
new FCM token and register it through the existing push-device sync flow.

- [ ] **Step 3: Retrieve and install generated Firebase SDK configuration**

Retrieve Android SDK configuration by the new Firebase app ID, not merely by
platform because the project now contains two Android apps.

Keep the old Firebase app ID recorded in the task notes. Its SDK configuration
remains downloadable from Firebase and is the rollback source; do not delete
the old app.

Replace `frontend/android/app/google-services.json` with the exact generated
JSON. Do not copy the old `mobilesdk_app_id`, API client, or package entry.

Verify locally:

```powershell
$firebaseConfig = Get-Content -Raw 'frontend/android/app/google-services.json' | ConvertFrom-Json
$client = $firebaseConfig.client | Where-Object {
  $_.client_info.android_client_info.package_name -eq 'com.hellovietnam.app'
}
if ($null -eq $client) { throw 'Firebase config has no com.hellovietnam.app client' }
Write-Output $client.client_info.mobilesdk_app_id
```

Expected: one non-empty Firebase Android app ID is printed.

- [ ] **Step 4: Update Gradle and manifest identity**

In `frontend/android/app/build.gradle.kts`, set:

```kotlin
namespace = "com.hellovietnam.app"
```

and:

```kotlin
applicationId = "com.hellovietnam.app"
```

In `frontend/android/app/src/main/AndroidManifest.xml`, set:

```xml
<data android:scheme="com.hellovietnam.app" />
```

- [ ] **Step 5: Move and update MainActivity**

Move the Kotlin file to:

```text
frontend/android/app/src/main/kotlin/com/hellovietnam/app/MainActivity.kt
```

Use this content:

```kotlin
package com.hellovietnam.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

Delete only the now-empty old package directories under
`frontend/android/app/src/main/kotlin/com/example/hellovietnam`.

- [ ] **Step 6: Verify native identity and ignored Firebase config**

Run from the repository root:

```powershell
rg -n 'com\.hellovietnam\.app' frontend/android/app/build.gradle.kts frontend/android/app/src/main frontend/android/app/src/main/kotlin
git check-ignore -v frontend/android/app/google-services.json
$tracked = git ls-files --error-unmatch frontend/android/app/google-services.json 2>$null
if ($LASTEXITCODE -eq 0) { throw 'google-services.json must not be tracked' }
```

Expected:

- Gradle reports the new namespace and application ID.
- Manifest and `MainActivity.kt` report the new package.
- `git check-ignore` identifies the repository ignore rule.
- `google-services.json` is not tracked.

- [ ] **Step 7: Run the Google Services Gradle task**

From `frontend/android`, ensure `JAVA_HOME` points to a JDK 17 installation,
then run:

```powershell
.\gradlew.bat :app:processDebugGoogleServices --console=plain
```

Expected: `BUILD SUCCESSFUL`; there is no “No matching client found for package
name” error.

- [ ] **Step 8: Commit only tracked native Android changes**

```powershell
git add -- frontend/android/app/build.gradle.kts frontend/android/app/src/main/AndroidManifest.xml frontend/android/app/src/main/kotlin/com/example/hellovietnam/MainActivity.kt frontend/android/app/src/main/kotlin/com/hellovietnam/app/MainActivity.kt
git diff --cached --check
git commit -m "build: migrate Android application ID"
```

Expected: the ignored `google-services.json` is absent from the commit.

---

### Task 4: Update Tests and Operational Documentation

**Files:**

- Modify: `backend/supabase/functions/ai-chat/ai_chat_domain_test.ts:176`
- Modify: `backend/supabase/functions/notifications/README.md:9-13`
- Modify: `huongdan.md:8-12`

**Interfaces:**

- Consumes: the final package `com.hellovietnam.app`.
- Produces: documentation and security-filter fixtures that no longer teach the retired package.

- [ ] **Step 1: Update the sanitized deep-link fixture**

Change the nested URL in `ai_chat_domain_test.ts` to:

```ts
href: "com.hellovietnam.app://profile",
```

The test expectation remains unchanged because the URL must still be stripped
from the model action payload.

- [ ] **Step 2: Update Firebase deployment documentation**

In both notification guides, change the Firebase Android app package to:

```text
com.hellovietnam.app
```

Keep the existing instructions that place `google-services.json` under
`frontend/android/app/` and prohibit committing it.

- [ ] **Step 3: Run the backend fixture test**

Run from `backend`:

```powershell
deno test --allow-env supabase/functions/ai-chat/ai_chat_domain_test.ts
```

Expected: the AI chat domain test passes, including “raw routes and URLs are
removed from an allowed action payload.” If Deno is not installed, report this
single verification as blocked by the local toolchain and continue with the
Flutter and Android checks.

- [ ] **Step 4: Audit non-historical project references**

Run from the repository root:

```powershell
$matches = rg -n -g '!docs/superpowers/**' -g '!ui-patches/**' -g '!*.patch' 'com\.example\.hellovietnam' frontend backend huongdan.md
$allowedIos = $matches | Where-Object { $_ -match 'frontend[\\/]ios[\\/]' }
$unexpected = $matches | Where-Object { $_ -notmatch 'frontend[\\/]ios[\\/]' }
$allowedIos
if ($unexpected) { $unexpected; throw 'Old Android package remains outside iOS' }
```

Expected: only iOS bundle identifier or URL-scheme references are printed.

- [ ] **Step 5: Commit documentation and fixture updates**

```powershell
git add -- backend/supabase/functions/ai-chat/ai_chat_domain_test.ts backend/supabase/functions/notifications/README.md huongdan.md
git diff --cached --check
git commit -m "docs: update production Android package"
```

---

### Task 5: Configure Supabase Auth Redirects

**External state:**

- Supabase project referenced by `Env.supabaseUrl`.

**Interfaces:**

- Consumes: `AppIdentity.loginCallbackUrl` and `AppIdentity.resetPasswordCallbackUrl`.
- Produces: an Auth redirect allowlist that accepts both production Android callbacks.

- [ ] **Step 1: Identify the linked Supabase project**

Read the project reference from the configured Supabase URL without printing
the anon key. Confirm it matches the project intended for the Android release.

Run from `backend`:

```powershell
npx supabase projects list
```

Expected: the configured project appears in the authenticated CLI account.

- [ ] **Step 2: Inspect existing Auth redirect URLs**

Use the available Supabase dashboard or management tooling to read the existing
Auth URL configuration. Record the current values before changing them.

Expected: unrelated web and development callback URLs remain identifiable for
preservation.

- [ ] **Step 3: Add production Android callbacks**

Add these exact entries:

```text
com.hellovietnam.app://login-callback
com.hellovietnam.app://reset-password
```

Do not remove any existing redirect. Do not add the retired package to a new
environment.

If no authenticated management tool is available, stop only this external
substep and report the two exact entries for the project owner to add in
Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.

- [ ] **Step 4: Verify redirect preservation**

Read the Auth URL configuration again.

Expected:

- Both new Android callbacks are present.
- Every unrelated pre-existing redirect is still present.

---

### Task 6: Full Verification and Release Handoff

**Files:**

- Verify only; no source changes expected.

**Interfaces:**

- Consumes: all deliverables from Tasks 1–5.
- Produces: evidence for tests, static analysis, Firebase match, Android build identity, and remaining manual release steps.

- [ ] **Step 1: Run all targeted Flutter tests**

Run from `frontend`:

```powershell
flutter test test/core/config/app_identity_test.dart test/app/deep_link_state_test.dart test/features/profile/domain/subscription_checkout_urls_test.dart test/features/profile/data/subscription_repository_test.dart test/features/notification/application/push_notification_service_test.dart
```

Expected: all targeted tests PASS.

- [ ] **Step 2: Run the full Flutter test suite**

Run from `frontend`:

```powershell
flutter test
```

Expected: the suite exits successfully with zero failing tests.

- [ ] **Step 3: Run Flutter static analysis**

Run from `frontend`:

```powershell
flutter analyze
```

Expected: exit code 0 with no analyzer errors.

- [ ] **Step 4: Resolve the local JDK without changing persistent user settings**

In the current PowerShell session, inspect these JDK 17 candidates:

```powershell
$jdkCandidates = @(
  "$env:ProgramFiles\Android\Android Studio\jbr",
  "$env:LOCALAPPDATA\Programs\Android Studio\jbr",
  "$env:ProgramFiles\Java\jdk-17"
)
$jdk = $jdkCandidates | Where-Object {
  Test-Path -LiteralPath (Join-Path $_ 'bin\java.exe')
} | Select-Object -First 1
if ($null -eq $jdk) { throw 'No local JDK 17 installation found' }
$env:JAVA_HOME = $jdk
& (Join-Path $env:JAVA_HOME 'bin\java.exe') -version
```

Expected: Java reports version 17 or the Android Studio JBR equivalent. If no
candidate exists, report the Android build as blocked by the local toolchain.

- [ ] **Step 5: Build the Android debug APK**

Run from `frontend` in the same PowerShell session:

```powershell
flutter clean
flutter pub get
flutter build apk --debug
```

Expected: `build/app/outputs/flutter-apk/app-debug.apk` is created and the build
exits successfully.

- [ ] **Step 6: Verify the generated application ID**

Read `frontend/android/local.properties` to locate the Android SDK. Find the
newest installed `apkanalyzer.bat`, then run:

```powershell
$sdkLine = Get-Content android/local.properties | Where-Object {
  $_ -like 'sdk.dir=*'
} | Select-Object -First 1
$androidSdk = ($sdkLine -replace '^sdk\.dir=', '') -replace '\\\\', '\'
$apkAnalyzer = Get-ChildItem -Path (Join-Path $androidSdk 'cmdline-tools') -Recurse -Filter 'apkanalyzer.bat' |
  Sort-Object FullName -Descending |
  Select-Object -First 1
if ($null -eq $apkAnalyzer) { throw 'apkanalyzer.bat not found in Android SDK' }
& $apkAnalyzer.FullName manifest application-id build/app/outputs/flutter-apk/app-debug.apk
```

Expected:

```text
com.hellovietnam.app
```

- [ ] **Step 7: Recheck Firebase and repository hygiene**

List Firebase Android apps again and verify both the old rollback app and the
new production app are active. Then run from the repository root:

```powershell
git check-ignore -v frontend/android/app/google-services.json
git status --short
git log --oneline -5
```

Expected:

- Firebase lists `com.example.hellovietnam` and `com.hellovietnam.app`.
- The SDK config remains ignored and untracked.
- Only intended package-migration commits plus pre-existing user work appear.

- [ ] **Step 8: Perform Android device smoke tests**

On an Android device or emulator with the new build:

1. Complete Google OAuth and confirm the browser returns to the app.
2. Request a password reset and confirm the link opens the reset flow.
3. Start a Stripe checkout and confirm both successful and cancelled returns
   reopen Upgrade Payment.
4. Sign in, allow notifications, and confirm a new row appears for the device
   in `public.user_push_device`.
5. Enqueue a test notification and confirm delivery and tap navigation.

Expected: all five flows use the new package and no callback targets the
retired scheme.

- [ ] **Step 9: Record the Google Play handoff**

Confirm with the project owner that the Google Play app draft selected for
upload reports package `com.hellovietnam.app`. Do not upload a release bundle
to a draft associated with `com.example.hellovietnam`.

The release is ready for Play upload only after the package shown in the built
artifact and the package shown in Play Console are identical.
