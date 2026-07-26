# Android Package and Firebase Migration Design

**Date:** 2026-07-27

## Goal

Migrate the Hello Vietnam Android application identity from
`com.example.hellovietnam` to the final production package
`com.hellovietnam.app`.

The migration must keep the Android build, Firebase Cloud Messaging, Supabase
authentication redirects, payment callbacks, and in-app deep links consistent.
The application is not currently released on Google Play, so the new package
will become the permanent Android application ID used for future releases.

## Scope

This migration covers the Android application and Android-specific runtime
configuration:

- Gradle `applicationId` and Android namespace.
- Kotlin package declaration and `MainActivity` source path.
- Firebase Android app registration and `google-services.json`.
- Android custom URL scheme and Flutter deep-link handling.
- Supabase authentication and password-reset redirect URLs.
- Android Stripe checkout success and cancellation callbacks.
- Android package name supplied to the map user agent.
- Tests and documentation that describe the Android package.

The generated iOS project is outside the scope. Its bundle identifiers and URL
schemes will remain unchanged because Hello Vietnam is not currently targeting
iOS.

## Current State

- The Gradle application ID and namespace are
  `com.example.hellovietnam`.
- `MainActivity.kt` uses package `com.example.hellovietnam`.
- The local Firebase configuration belongs to Android app
  `1:1061619391252:android:f86a43ae5b3092e54d0001` and declares package
  `com.example.hellovietnam`.
- Firebase project `hello-vietnam-26078` currently has no Android app registered
  with package `com.hellovietnam.app`.
- Authentication, password reset, payment callbacks, and deep-link routing use
  the old package string as their custom URL scheme.
- The FCM server integration uses project-level Firebase credentials and can
  continue using the same Firebase project.

## Chosen Approach

Perform a complete Android-only migration in one coordinated change.

The existing Firebase Android app will be preserved. A new Android app named
for Hello Vietnam will be registered in the same Firebase project with package
`com.hellovietnam.app`. Its generated SDK configuration will replace the local
`frontend/android/app/google-services.json`.

Keeping both Firebase app registrations is intentional. Firebase Android
package names cannot be changed after registration, and preserving the old app
provides a non-destructive rollback path while the new configuration is
verified.

## Application Identity Changes

Set both Gradle values to the new package:

```kotlin
namespace = "com.hellovietnam.app"
applicationId = "com.hellovietnam.app"
```

Move `MainActivity.kt` from:

```text
frontend/android/app/src/main/kotlin/com/example/hellovietnam/MainActivity.kt
```

to:

```text
frontend/android/app/src/main/kotlin/com/hellovietnam/app/MainActivity.kt
```

and change its Kotlin package declaration to `com.hellovietnam.app`.

The namespace and application ID will remain equal to avoid a split between
generated Android classes and the package used by Google Play and Firebase.

## Firebase and Push Notifications

Create a new Android app in Firebase project `hello-vietnam-26078` using the
exact, case-sensitive package `com.hellovietnam.app`. Download its Android SDK
configuration and replace the ignored local file:

```text
frontend/android/app/google-services.json
```

The downloaded file must contain a client whose
`client_info.android_client_info.package_name` equals
`com.hellovietnam.app`. The generated Firebase `mobilesdk_app_id` must come from
Firebase; it must not be copied from the old app or created manually.

The Supabase notification dispatcher and Firebase HTTP v1 service credentials
remain unchanged because the new Android app is registered inside the same
Firebase project. Devices installed under the new package will obtain new FCM
tokens, and the existing app flow will register those tokens with Supabase.

## Deep Links and External Callbacks

Use `com.hellovietnam.app` as the Android custom URL scheme everywhere the old
package was used:

```text
com.hellovietnam.app://login-callback
com.hellovietnam.app://reset-password
com.hellovietnam.app://upgrade-payment
com.hellovietnam.app://profile
```

Update:

- The Android manifest intent filter.
- Flutter deep-link recognition.
- Supabase authentication and password-reset redirect construction.
- Stripe checkout success and cancellation intent URLs.
- Tests that assert these URLs.
- Android-related documentation and examples.

The Supabase Auth redirect allowlist must include at least:

```text
com.hellovietnam.app://login-callback
com.hellovietnam.app://reset-password
```

If Supabase supports a wildcard entry for this custom scheme in the project's
current configuration, `com.hellovietnam.app://**` may be used instead. The
implementation must inspect the existing allowlist before adding entries and
must not remove unrelated redirects.

The payment callback is handled locally through the Android manifest and app
router. Any externally configured Stripe or Supabase checkout URLs must be
checked for the old scheme and updated if present.

## Google Play Handling

`com.hellovietnam.app` is the final Android application ID. Future Android App
Bundles must use this package.

Before uploading the release bundle:

- If Play Console already has an app draft associated with
  `com.hellovietnam.app`, use that draft.
- If the existing draft is associated only with `com.example.hellovietnam`,
  create or select a Play app entry for `com.hellovietnam.app`.
- Do not upload a bundle built with the old package as a release for the new
  app entry.

Google Play Console changes are a release-management step and are not required
to verify the local Android build.

## Error Handling and Safety

- Do not manually edit the old Firebase client's package name or app ID.
- Do not delete the old Firebase Android app during this migration.
- Confirm the active Firebase project is `hello-vietnam-26078` before creating
  the new app.
- If an Android app with `com.hellovietnam.app` appears before creation, reuse
  it rather than creating a duplicate.
- Keep `google-services.json` ignored by Git and do not commit its API keys.
- Do not alter existing user changes in the working tree.
- If Supabase redirect settings cannot be changed through the available
  tooling, document the exact entries the project owner must add before auth
  callbacks are tested.

## Verification

The migration is complete only when all applicable checks pass:

1. Firebase lists an active Android app with package
   `com.hellovietnam.app`.
2. The local `google-services.json` contains the matching Firebase client.
3. Runtime Android and Flutter source contains no
   `com.example.hellovietnam` references.
4. The iOS project remains unchanged.
5. Relevant deep-link, auth, payment, notification, and map tests pass.
6. `flutter analyze` passes for the frontend.
7. The Google Services Gradle task resolves a client without a package mismatch.
8. A debug Android build completes when the local Java/Android toolchain is
   available.
9. The generated APK or App Bundle reports application ID
   `com.hellovietnam.app`.
10. Manual smoke tests cover login callback, password reset, payment return, and
    FCM token registration on an Android device or emulator.

If build verification is blocked by a missing local Java or Android SDK, that
environment limitation must be reported explicitly rather than treating the
migration as fully verified.

## Rollback

Source changes can be reverted as a single coordinated commit. The previous
ignored `google-services.json` can be restored from a secure local backup or
downloaded again from the old Firebase Android app.

The newly registered Firebase app does not need to be deleted for rollback. The
old Firebase app remains available, so restoring the old Gradle application ID,
source package, deep-link scheme, and matching SDK configuration returns the
project to its previous Android identity.
