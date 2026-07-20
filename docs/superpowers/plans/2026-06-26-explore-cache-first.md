# Explore Cache-First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the initial Explore screen render faster by showing cached Explore sections immediately when available, then refreshing them in the background.

**Architecture:** Keep the change frontend-only. Add lightweight JSON cache support inside `ExploreRepository`, then update `ExplorePage` to use a cache-first state flow instead of waiting entirely on a single `FutureBuilder`. Reuse the existing `LocalStorage` pattern already used elsewhere in the app.

**Tech Stack:** Flutter, SharedPreferences via `LocalStorage`, Supabase Edge Functions, widget/unit tests

---

### Task 1: Add Explore Sections Cache Support

**Files:**
- Modify: `frontend/lib/features/explore/data/explore_repository.dart`
- Modify: `frontend/lib/features/explore/domain/explore_item.dart`
- Modify: `frontend/lib/features/explore/domain/explore_province.dart`
- Test: `frontend/test/features/explore/data/explore_repository_test.dart`

- [ ] **Step 1: Write the failing repository cache tests**
- [ ] **Step 2: Run the test to verify cache behavior is missing**
- [ ] **Step 3: Add JSON serialization helpers for `ExploreItem`, `ExploreCategory`, `ExploreProvince`, and `ExploreSectionsData`**
- [ ] **Step 4: Add local cache read/write helpers plus TTL handling in `ExploreRepository`**
- [ ] **Step 5: Re-run the targeted test and make sure it passes**

### Task 2: Switch ExplorePage To Cache-First UI Flow

**Files:**
- Modify: `frontend/lib/features/explore/presentation/explore_page.dart`
- Test: `frontend/test/features/explore/presentation/explore_page_test.dart`

- [ ] **Step 1: Write the failing page test for cached-first rendering**
- [ ] **Step 2: Run the test to verify current Explore page waits on loading**
- [ ] **Step 3: Replace the pure `FutureBuilder` flow with local page state that can show cache first and refresh in background**
- [ ] **Step 4: Keep existing loading/error behavior for true cache-miss cases**
- [ ] **Step 5: Re-run the targeted page test and make sure it passes**

### Task 3: Verify Refresh Fallback Behavior

**Files:**
- Modify: `frontend/test/features/explore/presentation/explore_page_test.dart`

- [ ] **Step 1: Add a failing test proving stale cached content stays visible if refresh fails**
- [ ] **Step 2: Run it and verify it fails for the expected reason**
- [ ] **Step 3: Adjust page-state refresh error handling if needed**
- [ ] **Step 4: Re-run the targeted page test and make sure it passes**

### Task 4: Final Validation

**Files:**
- Verify only

- [ ] **Step 1: Run targeted tests**
- [ ] **Step 2: Run focused analysis on modified Explore files**
- [ ] **Step 3: Re-check the spec for coverage before closing**

## Self-Review

- Spec coverage:
  - cache initial Explore payload: Task 1
  - render cache immediately: Task 2
  - refresh in background: Tasks 1-2
  - preserve cache on refresh failure: Task 3
  - keep current loading/error fallback on cache miss: Task 2
- Placeholder scan:
  - no TBD/TODO placeholders
  - all tasks map directly to shipped code and tests
- Type consistency:
  - `ExploreSectionsData` remains the UI contract
  - cache support stays inside `ExploreRepository`
  - `ExplorePage` consumes cache-aware repository behavior through explicit page state
