# Detail Gallery Source Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make detail-page hero images use `cover_image` while the gallery below “What to expect” uses only the database `gallery` column.

**Architecture:** The explore edge function will return explicit `coverImage` and `galleryImages` fields while retaining the combined `images` field for compatibility. Flutter will store both explicit fields on `ItemDetail`, use `coverImage` for the hero, and use `galleryImages` for the lower gallery with legacy fallback behavior.

**Tech Stack:** TypeScript/Deno Supabase Edge Function, Dart/Flutter, Flutter widget tests.

## Global Constraints

- Preserve existing `images` response and fallback behavior for legacy callers.
- Keep the hero sourced from cover-image candidates only.
- Keep the lower gallery sourced from gallery candidates only.
- Do not change unrelated detail-page sections.

---

### Task 1: Add explicit image fields to the explore detail response

**Files:**
- Modify: `backend/supabase/functions/explore/explore_handler.ts`
- Test: `backend/supabase/functions/explore/explore_handler_test.ts` if existing handler tests expose the mapper; otherwise add focused helper coverage beside the handler.

**Interfaces:**
- Produces response fields `coverImage: string | null` and `galleryImages: string[]`.

- [ ] **Step 1: Add a focused failing assertion for separated image sources**

  Exercise a detail row containing `cover_image: "cover.jpg"` and `gallery: ["gallery-1.jpg", "gallery-2.jpg"]`, asserting the response separates them.

- [ ] **Step 2: Run the focused handler test and verify it fails**

  Run: `cd backend/supabase/functions/explore; deno test --allow-env --allow-net explore_handler_test.ts`

  Expected: failure because the detail response does not yet contain the explicit fields.

- [ ] **Step 3: Implement the response fields**

  Add `collectCoverImage` using `config.imageCandidates`, add `collectGalleryImages` using `config.galleryCandidates`, and return both alongside the existing `images: collectItemImages(row, config)`.

- [ ] **Step 4: Run the focused handler test again**

  Run the same Deno test command and verify the separated-field assertions pass.

### Task 2: Model and parse explicit cover/gallery images in Flutter

**Files:**
- Modify: `frontend/lib/features/item_detail/domain/item_detail_models.dart`
- Modify: `frontend/lib/features/item_detail/data/item_detail_repository.dart`
- Test: `frontend/test/features/item_detail/data/item_detail_repository_test.dart`

**Interfaces:**
- `ItemDetail.coverImage` is a nullable `String`.
- `ItemDetail.galleryImages` is an immutable `List<String>`.

- [ ] **Step 1: Add failing repository expectations**

  Extend the fake detail response with `coverImage` and `galleryImages`, then assert both values are parsed while `images` remains available.

- [ ] **Step 2: Run the focused Flutter test and verify it fails**

  Run: `cd frontend; flutter test test/features/item_detail/data/item_detail_repository_test.dart`

  Expected: compile/test failure because the model does not expose the new fields.

- [ ] **Step 3: Add the model fields and copyWith support**

  Add optional constructor fields, getters/fallback normalization as needed, and preserve existing required constructor call sites by using defaults.

- [ ] **Step 4: Parse explicit fields with compatibility fallback**

  Parse `coverImage`; if absent, use the first parsed combined image. Parse `galleryImages`; if absent, use an empty list so the UI can fall back to legacy images only where necessary.

- [ ] **Step 5: Run the focused repository test**

  Run the same Flutter test command and verify it passes.

### Task 3: Bind the detail UI to the separated fields

**Files:**
- Modify: `frontend/lib/features/item_detail/presentation/shared_item_detail_page.dart`
- Test: `frontend/test/features/item_detail/presentation/shared_item_detail_page_test.dart`

**Interfaces:**
- Hero receives a single cover image list.
- Lower gallery receives gallery images only, with legacy fallback when explicit gallery data is unavailable.

- [ ] **Step 1: Add a failing widget test**

  Build `SharedItemDetailPage` with a cover image and two gallery images, then assert the hero image source contains only the cover path and the lower gallery contains the gallery paths.

- [ ] **Step 2: Run the focused widget test and verify it fails**

  Run: `cd frontend; flutter test test/features/item_detail/presentation/shared_item_detail_page_test.dart`

  Expected: failure because the page currently uses the combined `images` list in both places.

- [ ] **Step 3: Update the page bindings**

  Pass `[_detail.coverImage]` to `_HeroImageCarousel` when available, and render `_detail.galleryImages` after “What to expect”; use `_detail.images` only as a legacy fallback.

- [ ] **Step 4: Run the focused widget test**

  Run the same Flutter test command and verify it passes.

### Task 4: Run final verification

**Files:**
- Verify: all files changed in Tasks 1–3.

- [ ] **Step 1: Format Dart files**

  Run: `cd frontend; dart format lib/features/item_detail/domain/item_detail_models.dart lib/features/item_detail/data/item_detail_repository.dart lib/features/item_detail/presentation/shared_item_detail_page.dart test/features/item_detail`

- [ ] **Step 2: Run focused tests**

  Run the repository and widget tests together and verify exit code 0.

- [ ] **Step 3: Run static analysis**

  Run: `cd frontend; flutter analyze`

- [ ] **Step 4: Review the diff and report any environment-blocked checks**

  Run: `git diff --check; git status --short`

