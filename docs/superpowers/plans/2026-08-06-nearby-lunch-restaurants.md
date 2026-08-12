# Nearby Lunch Restaurants via Google Maps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a coordinate-based restaurant search action after the lunch anchor on every non-empty itinerary day.

**Architecture:** A pure lunch-anchor selector identifies the last real place starting before noon, with a first-place fallback for afternoon-only days. The existing Google Maps URL builder receives a coordinate search query, while a focused card owns the UI state and accessibility text.

**Tech Stack:** Flutter/Dart, `url_launcher`, `flutter_test`.

## Global Constraints

- Do not change Supabase, backend APIs, or database schema.
- Use existing `TripPlannerActivityData.lat` and `.lng`; coordinates are the primary search location.
- Keep the feature available for every day containing at least one real place.

---

### Task 1: Define lunch-anchor selection behavior

**Files:**
- Create: `frontend/lib/features/planner/presentation/lunch_anchor_selector.dart`
- Test: `frontend/test/features/planner/presentation/lunch_anchor_selector_test.dart`

**Interfaces:**
- `TripPlannerActivityData? selectLunchAnchor(List<TripPlannerActivityData> activities)` returns the selected real activity or `null` for an empty/all-lunch-break day.

- [ ] **Step 1: Write the failing tests** for a normal morning schedule, an afternoon-only schedule, lunch-break filtering, invalid time strings, and empty input.
- [ ] **Step 2: Run the selector test** and confirm it fails because the selector does not exist.
- [ ] **Step 3: Implement the pure selector** with `HH:mm` parsing, pre-noon filtering, last-match selection, and first-real-place fallback.
- [ ] **Step 4: Run the selector test** and confirm all cases pass.

### Task 2: Add the lunch discovery card and page integration

**Files:**
- Create: `frontend/lib/features/planner/presentation/widgets/lunch_discovery_card.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_day_detail_page.dart`
- Test: `frontend/test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart`

**Interfaces:**
- `LunchDiscoveryCard` accepts `anchorName`, `enabled`, and `VoidCallback? onTap`.
- `TripDayDetailPage` uses `openGoogleMapsSearchQuery` with `restaurants near $lat,$lng, Vietnam`.

- [ ] **Step 1: Write widget tests** proving the card appears after the selected anchor, forwards the anchor coordinates, renders for afternoon-only days, and disables itself for invalid coordinates.
- [ ] **Step 2: Run the widget test** and confirm it fails because the card and selector are absent.
- [ ] **Step 3: Implement the card and page integration** without changing the existing route button or activity cards.
- [ ] **Step 4: Run the widget test** and confirm all cases pass.

### Task 3: Verify URL construction and planner tests

**Files:**
- Modify: `frontend/test/core/utils/maps_launcher_test.dart`

- [ ] **Step 1: Add a coordinate-based restaurant query assertion** for Hanoi coordinates and assert that the query contains the coordinates.
- [ ] **Step 2: Run the focused Maps and planner tests.**
- [ ] **Step 3: Run `git diff --check` and inspect the final diff for unrelated changes.
