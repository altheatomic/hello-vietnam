# AI Recognition History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically persist the latest 30 successful AI Recognition results locally and provide a history screen with per-entry deletion.

**Architecture:** Recognition-result serialization lives with the API models, while a dedicated history repository owns user-scoped SharedPreferences persistence and thumbnail compression. The recognition page saves only after successful analysis, and a separate routed page reads and deletes entries.

**Tech Stack:** Flutter, Dart, SharedPreferences, Flutter image codec, GoRouter, flutter_test.

## Global Constraints

- Store history locally and never upload it specifically for history.
- Save at most 30 entries, newest first.
- Store a compressed resized PNG thumbnail, not the original image.
- A history persistence failure must not hide a successful recognition result.
- Keep existing uncommitted AI Recognition database-linking changes intact.

---

### Task 1: Serializable Recognition Models

**Files:**
- Modify: `frontend/lib/features/ai_search/data/ai_search_service.dart`
- Modify: `frontend/test/features/ai_search/data/ai_search_service_test.dart`

**Interfaces:**
- Produces: `AiSearchResult.toJson() -> Map<String, dynamic>`
- Produces: `AiSearchDatabaseMatch.toJson() -> Map<String, dynamic>`

- [ ] **Step 1: Write a failing JSON round-trip test**

Create an `AiSearchResult`, call `toJson()`, reconstruct it with
`AiSearchResult.fromJson()`, and assert the detected name, lists, confidence,
and database match are unchanged.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/features/ai_search/data/ai_search_service_test.dart
```

Expected: compilation fails because `toJson` does not exist.

- [ ] **Step 3: Implement symmetric JSON serialization**

Add:

```dart
Map<String, dynamic> toJson() => <String, dynamic>{
  'result_type': resultType,
  'confidence': confidence,
  'detected_name': detectedName,
  'subtitle': subtitle,
  'summary': summary,
  'location_hint': locationHint,
  'category_text': categoryText,
  'primary_tags': primaryTags,
  'secondary_tags': secondaryTags,
  'best_time': bestTime,
  'note': note,
  'cultural_significance': culturalSignificance,
  'usage_bullets': usageBullets,
  'production_method': productionMethod,
  'alternative_names': alternativeNames,
  'price_range': priceRange,
  'suggested_places': suggestedPlaces,
  if (databaseMatch != null) 'db_match': databaseMatch!.toJson(),
};
```

The database-match JSON must include `status: matched`, category, id, name,
match score, and optional image path so the existing parser accepts it.

- [ ] **Step 4: Run the focused test and verify it passes**

Run the command from Step 2. Expected: all tests pass.

---

### Task 2: Local History Repository

**Files:**
- Create: `frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart`
- Create: `frontend/test/features/ai_search/data/ai_recognition_history_repository_test.dart`

**Interfaces:**
- Produces: `AiRecognitionHistoryEntry`
- Produces: `AiRecognitionHistoryRepository.load()`
- Produces: `AiRecognitionHistoryRepository.save(...)`
- Produces: `AiRecognitionHistoryRepository.delete(String id)`

- [ ] **Step 1: Add failing repository tests**

Use `SharedPreferences.setMockInitialValues` and verify:

```dart
expect(await repository.load(), isEmpty);
await repository.save(result: result, imageBytes: validImageBytes);
expect((await repository.load()).single.result.detectedName, 'Bun bo Hue');
```

Also save 31 entries and assert only 30 remain in newest-first order, inject a
malformed JSON value and assert it is ignored, then delete one ID and assert
only that entry is removed.

- [ ] **Step 2: Run the repository tests and verify they fail**

Run:

```powershell
flutter test test/features/ai_search/data/ai_recognition_history_repository_test.dart
```

Expected: compilation fails because the repository does not exist.

- [ ] **Step 3: Add thumbnail support with Flutter's image codec**

Decode the selected image at a target width of 240 pixels without upscaling,
encode it as PNG, and store the resulting base64 string. This avoids adding a
network-fetched dependency and remains compatible with Android and CanvasKit.

- [ ] **Step 4: Implement user-scoped persistence**

Persist a JSON array under:

```dart
'ai_recognition_history_v1_${currentUserId ?? 'anonymous'}'
```

Use a generated ID based on microseconds plus a stable suffix, UTC timestamps,
and `AiSearchResult.toJson()`. Catch malformed entries individually. Insert new
entries at index zero and trim with `take(30)`.

- [ ] **Step 5: Run the repository tests and verify they pass**

Run the command from Step 2. Expected: all tests pass.

---

### Task 3: Automatic Save And History Navigation

**Files:**
- Modify: `frontend/lib/features/ai_search/presentation/ai_search_page.dart`
- Create: `frontend/test/features/ai_search/presentation/ai_search_history_navigation_test.dart`

**Interfaces:**
- Consumes: `AiRecognitionHistoryRepository.save`
- Produces: History button that navigates to `AppRoutes.aiSearchHistory`

- [ ] **Step 1: Write failing widget tests**

Inject a fake history repository into `AiSearchPage`. Verify a button with key
`ai-search-history-button` exists and calls the supplied navigation callback.
Test successful analysis separately by invoking the extracted save helper and
asserting the fake repository receives the result and selected bytes.

- [ ] **Step 2: Run the widget test and verify it fails**

Run:

```powershell
flutter test test/features/ai_search/presentation/ai_search_history_navigation_test.dart
```

Expected: compilation fails because the injection points and key do not exist.

- [ ] **Step 3: Add the History control and automatic save**

Add an icon button using `Icons.history_rounded` to the initial header. After
`analyzeImage` succeeds, await the history save before showing the result, but
catch save errors separately and keep the successful result visible.

- [ ] **Step 4: Run the widget test and verify it passes**

Run the command from Step 2. Expected: all tests pass.

---

### Task 4: History Screen And Router

**Files:**
- Create: `frontend/lib/features/ai_search/presentation/ai_recognition_history_page.dart`
- Create: `frontend/test/features/ai_search/presentation/ai_recognition_history_page_test.dart`
- Modify: `frontend/lib/app/router.dart`

**Interfaces:**
- Consumes: `AiRecognitionHistoryRepository.load/delete`
- Produces: route constant `/ai-search/history`
- Produces: per-entry delete button key `ai-history-delete-<entryId>`

- [ ] **Step 1: Write failing history-page tests**

Pump the page with an in-memory fake repository. Verify the empty state, then
provide one entry and verify its thumbnail, detected name, confidence, type,
and timestamp. Tap the delete icon, confirm the dialog, and assert the entry is
removed from both repository and UI.

- [ ] **Step 2: Run the page test and verify it fails**

Run:

```powershell
flutter test test/features/ai_search/presentation/ai_recognition_history_page_test.dart
```

Expected: compilation fails because the page does not exist.

- [ ] **Step 3: Implement the history page**

Use a full-width scrollable list, newest first. Keep each entry as one compact
card with a stable thumbnail size, result metadata, optional database-match
label, and a delete icon with tooltip. Use a confirmation dialog before
deletion and show a retry state if loading fails.

- [ ] **Step 4: Register the route**

Add:

```dart
static const aiSearchHistory = '/ai-search/history';
```

and a root-navigator `GoRoute` that builds `AiRecognitionHistoryPage`.

- [ ] **Step 5: Run focused and full verification**

Run:

```powershell
flutter test test/features/ai_search
flutter analyze
flutter test
```

Expected: no analyzer issues and all tests pass.
