# Popular Apps Android Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the Popular Apps Android experience with compact Apple-inspired filters, bundled official app logos, current app data, and external Google Play launching.

**Architecture:** Keep the existing page/card/detail structure and mock-data source. Store app logos as local assets for predictable rendering, keep one Google Play URL per detail post, and inject an optional external URL opener into the detail page so launch behavior can be tested without opening another application.

**Tech Stack:** Flutter, Material, `url_launcher`, Flutter widget tests.

## Global Constraints

- Android only; every Open/Download action targets Google Play.
- Replace Gojek with the current Green SM application formerly branded Xanh SM.
- Rename VinID to Techcombank OneU while retaining its current Google Play package.
- Keep filter controls compact visually while preserving a minimum 44 logical-pixel touch target.
- Bundle real application logos under `frontend/assets/images/popular_apps/`.

---

### Task 1: Lock the refreshed page and data behavior with tests

**Files:**
- Create: `frontend/test/features/popular_apps/popular_apps_page_test.dart`
- Create: `frontend/test/features/popular_apps/popular_apps_detail_test.dart`

**Interfaces:**
- Consumes: `PopularAppsPage`, `PopularAppsDetailPage`, `popularAppsItems`, and `popularAppsPosts`.
- Produces: regression coverage for title copy, compact filters, current app IDs, local logo paths, Google Play URLs, and external launching.

- [ ] **Step 1: Write failing page/data tests**

Test that the page renders `Popular Apps`, does not render `Essential Apps`, gives the category strip a 44px touch region with compact pills, removes `gojek` and `vinid`, includes `green_sm` and `oneu`, uses local logo paths, and gives every post a `play.google.com/store/apps/details` URL.

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/features/popular_apps/popular_apps_page_test.dart`

Expected: failures for the old title, oversized filters, old IDs, remote logo URLs, and website download URLs.

- [ ] **Step 3: Write failing detail launch test**

Pump a Grab detail page with an injected launcher, tap `Open / Download Grab`, and assert the captured URI is `https://play.google.com/store/apps/details?id=com.grabtaxi.passenger`.

- [ ] **Step 4: Run test to verify RED**

Run: `flutter test test/features/popular_apps/popular_apps_detail_test.dart`

Expected: compile failure because the injectable launcher interface does not exist yet.

### Task 2: Bundle official Android app logos and refresh app data

**Files:**
- Create: `frontend/assets/images/popular_apps/*.png`
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/features/popular_apps/data/popular_apps_mock_data.dart`
- Modify: `frontend/lib/features/popular_apps/presentation/widgets/popular_apps_cart.dart`
- Modify: `frontend/lib/features/popular_apps/presentation/popular_apps_detail.dart`

**Interfaces:**
- Consumes: official Google Play app pages and the existing `logoUrl` field.
- Produces: local `logoUrl` asset paths and `Image.asset` rendering in list and detail views.

- [ ] **Step 1: Download the verified official icons**

Save one icon per current app using stable lowercase filenames under `assets/images/popular_apps/`.

- [ ] **Step 2: Register and render the logo assets**

Add the asset directory to `pubspec.yaml`. Update both logo renderers to load local paths with `Image.asset` and retain their existing fallback widgets.

- [ ] **Step 3: Refresh IDs, names, descriptions, guides, and Play URLs**

Replace Gojek with Green SM (`com.gsm.customer`), replace VinID with Techcombank OneU (`com.vingroup.vinid`), and set all eleven `downloadUrl` values to their verified Google Play pages.

- [ ] **Step 4: Run page/data tests to verify GREEN**

Run: `flutter test test/features/popular_apps/popular_apps_page_test.dart`

Expected: all tests pass.

### Task 3: Apply compact Apple-style filters and title copy

**Files:**
- Modify: `frontend/lib/features/popular_apps/presentation/popular_apps_page.dart`
- Modify: `frontend/lib/features/popular_apps/presentation/widgets/popular_apps_category_tabs.dart`

**Interfaces:**
- Consumes: existing category list and callback.
- Produces: `Popular Apps` header and compact animated capsule filters with a 44px touch target.

- [ ] **Step 1: Change the header title**

Replace the hard-coded `Essential Apps` copy with `Popular Apps`.

- [ ] **Step 2: Compact the filters**

Use a 44px strip, 36px visual capsule, 14px horizontal padding, 13px semibold text, a subtle frosted fill, and a 180ms ease-out selection animation.

- [ ] **Step 3: Run page tests to verify GREEN**

Run: `flutter test test/features/popular_apps/popular_apps_page_test.dart`

Expected: all tests pass.

### Task 4: Open Google Play externally from app details

**Files:**
- Modify: `frontend/lib/features/popular_apps/presentation/popular_apps_detail.dart`

**Interfaces:**
- Produces: optional `Future<bool> Function(Uri)` launcher parameter on `PopularAppsDetailPage`.
- Uses: `launchUrl(uri, mode: LaunchMode.externalApplication)` by default.

- [ ] **Step 1: Add the injectable launcher and async handler**

Parse `post.downloadUrl`, call the injected launcher in tests or `url_launcher` in production, and show a concise snackbar only when launch returns false or throws.

- [ ] **Step 2: Run detail test to verify GREEN**

Run: `flutter test test/features/popular_apps/popular_apps_detail_test.dart`

Expected: the captured URI exactly matches Grab's Google Play page.

### Task 5: Verify the complete flow

**Files:**
- Verify: all changed Popular Apps files and assets.

- [ ] **Step 1: Format and analyze**

Run: `dart format lib/features/popular_apps test/features/popular_apps`

Run: `flutter analyze`

Expected: no formatting changes remain and analyzer reports no issues.

- [ ] **Step 2: Run all Popular Apps tests**

Run: `flutter test test/features/popular_apps`

Expected: all tests pass.

- [ ] **Step 3: Run on Android**

Open Popular Apps on the existing emulator, verify the title, filter proportions, real logos, Green SM and Techcombank OneU cards, then open a detail and confirm the CTA hands off to Google Play.
