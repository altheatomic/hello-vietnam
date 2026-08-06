# Accommodation Zone Recommendation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Module 2 accommodation-zone recommendation and show coordinate-based Google Maps hotel search links after itinerary generation without changing Module 3.

**Architecture:** A pure Python recommender evaluates contiguous day partitions from Module 2 day centroids using a 60/40 mean-versus-worst-day distance objective. It returns one or more zone coordinates in the existing trip response; Flutter parses the optional payload and renders a result-page card that builds Google Maps links from coordinates.

**Tech Stack:** Python, existing Haversine helper, FastAPI response dictionaries, Flutter/Dart, `url_launcher`, `flutter_test`.

## Global Constraints

- `MIN_ZONE_SEPARATION_KM = 50.0`.
- `MIN_TRAVEL_COST_REDUCTION_RATIO = 0.35`.
- `LONG_TRIP_MIN_DAYS = 5` and `MIN_DAYS_PER_ZONE = 2`.
- Do not change Module 3 start-point derivation, route optimization, or day ordering.
- Do not add Supabase schema, hotel inventory, price, availability, Goong, Google Routes, or backend map API calls.
- Use coordinates as the Google Maps search location; do not infer the location from province/place names alone.
- Preserve all pre-existing working-tree changes and only stage files belonging to this feature when committing.

---

### Task 1: Add the pure accommodation recommender contract

**Files:**
- Create: `cf_service/services/accommodation_recommendation.py`
- Test: `cf_service/test_accommodation_recommendation.py`

**Interfaces:**
- `build_accommodation_recommendation(day_clusters: list[dict], *, min_zone_separation_km: float = 50.0, min_cost_reduction_ratio: float = 0.35, long_trip_min_days: int = 5, min_days_per_zone: int = 2) -> dict | None`
- The result contains `version`, `strategy`, `zones`, and `evaluation` fields described in the design spec.
- A day cluster is usable only when its `centroid` is a valid `(latitude, longitude)` pair.

- [ ] **Step 1: Write failing unit tests for short trips and missing coordinates.**

```python
def test_short_trip_always_returns_one_zone():
    result = build_accommodation_recommendation([
        _day(1, (21.02, 105.84)),
        _day(2, (21.03, 105.85)),
        _day(3, (21.04, 105.86)),
    ])
    assert result["strategy"] == "single_zone"
    assert len(result["zones"]) == 1


def test_missing_day_centroid_returns_none_without_crashing():
    assert build_accommodation_recommendation([_day(1, None), _day(2, (21.0, 105.8))]) is None
```

- [ ] **Step 2: Run the focused tests and confirm the expected missing-module failure.**

Run from `cf_service`:

```powershell
python -m pytest test_accommodation_recommendation.py -q
```

Expected: collection fails because `services.accommodation_recommendation` does not exist.

- [ ] **Step 3: Implement validation, single-zone selection, and result serialization.**

Implementation requirements:

```python
def build_accommodation_recommendation(day_clusters, *, ...):
    usable_days = [day for day in day_clusters if _valid_centroid(day.get("centroid"))]
    if len(usable_days) != len(day_clusters) or not usable_days:
        return None
    if len(usable_days) < long_trip_min_days:
        return _recommend_for_partition([usable_days], ...)
```

The one-zone center is the day-centroid medoid: choose the existing day centroid with the lowest total distance to all usable day centroids. Keep numeric output rounded to six decimals for coordinates and four decimals for ratios/costs.

- [ ] **Step 4: Run the focused tests and confirm they pass.**

Run:

```powershell
python -m pytest test_accommodation_recommendation.py -q
```

Expected: 2 passing tests.

### Task 2: Add contiguous multi-zone evaluation and threshold tests

**Files:**
- Modify: `cf_service/services/accommodation_recommendation.py`
- Modify: `cf_service/test_accommodation_recommendation.py`

**Interfaces:**
- Candidate partitions are contiguous day ranges and each zone has at least `min_days_per_zone` days.
- `cost = 0.6 * mean(day_to_zone_distance) + 0.4 * max(day_to_zone_distance)`.
- A multi-zone candidate is accepted only when adjacent zone centers are at least 50 km apart and its reduction ratio is at least 35%.

- [ ] **Step 1: Add failing tests for accepted and rejected splits.**

```python
def test_separated_seven_day_trip_returns_two_contiguous_zones():
    result = build_accommodation_recommendation([
        _day(1, (21.02, 105.84)), _day(2, (21.03, 105.85)), _day(3, (21.04, 105.86)),
        _day(4, (20.85, 106.60)), _day(5, (20.86, 106.61)),
        _day(6, (20.87, 106.62)), _day(7, (20.88, 106.63)),
    ])
    assert result["strategy"] == "multi_zone"
    assert [(z["day_from"], z["day_to"]) for z in result["zones"]] == [(1, 3), (4, 7)]


def test_distance_under_threshold_keeps_one_zone():
    result = build_accommodation_recommendation([
        _day(1, (21.02, 105.84)), _day(2, (21.03, 105.85)), _day(3, (21.04, 105.86)),
        _day(4, (21.12, 106.20)), _day(5, (21.13, 106.21)),
    ])
    assert result["strategy"] == "single_zone"


def test_cost_reduction_under_threshold_keeps_one_zone():
    result = build_accommodation_recommendation(
        [_day(i, (21.02 + i * 0.01, 105.84 + i * 0.01)) for i in range(1, 8)],
        min_zone_separation_km=1.0,
        min_cost_reduction_ratio=0.99,
    )
    assert result["strategy"] == "single_zone"
```

- [ ] **Step 2: Run the tests and confirm the new tests fail for the absent partition evaluator.**

Run:

```powershell
python -m pytest test_accommodation_recommendation.py -q
```

Expected: the short-trip tests pass and the multi-zone tests fail because partition evaluation is not implemented.

- [ ] **Step 3: Implement bounded contiguous partition enumeration.**

Use these limits:

```python
max_zones = 2 if total_days <= 8 else 3 if total_days <= 14 else 4
```

Enumerate split points only when every segment has at least `min_days_per_zone`; evaluate one through `max_zones` zones. Choose the candidate with the lowest cost, then apply the separation and reduction gates against the one-zone baseline. If no candidate passes both gates, return the one-zone result.

- [ ] **Step 4: Run the full recommender test file and refactor only after green.**

Run:

```powershell
python -m pytest test_accommodation_recommendation.py -q
```

Expected: all tests pass with no warnings or errors.

### Task 3: Attach the recommendation to Module 2 and the trip response

**Files:**
- Modify: `cf_service/services/module2_algorithm.py`
- Modify: `cf_service/services/trip_planner.py`
- Modify: `cf_service/test_accommodation_recommendation.py`
- Modify: `cf_service/test_module2_eval.py` only if an existing response assertion needs the new optional field

**Interfaces:**
- `build_module2_result()` adds `accommodation_recommendation` after final day centroids and place counts are recomputed.
- `TripPlannerService.plan()` includes the same object at response top level.

- [ ] **Step 1: Add a failing integration assertion that Module 2 exposes the recommendation.**

```python
def test_module2_result_contains_accommodation_recommendation():
    result = build_module2_result(_synthetic_places(), "2026-08-01", "2026-08-03", "balanced")
    assert "accommodation_recommendation" in result
```

- [ ] **Step 2: Run the focused integration test and confirm it fails because the field is absent.**

Run:

```powershell
python -m pytest test_accommodation_recommendation.py -q
```

- [ ] **Step 3: Call the recommender after Module 2 repair finalization.**

Add the field to both the empty-candidate return and normal return. Do not alter any place movement, `day_clusters` contents, Module 3 invocation, or `_derive_start_point()` logic. In `TripPlannerService.plan()`, assign:

```python
accommodation_recommendation = m2_result.get("accommodation_recommendation")
```

and add it to the returned response dictionary without placing it inside `days`.

- [ ] **Step 4: Run focused Module 2 tests and the existing Module 2 evaluation.**

Run:

```powershell
python -m pytest test_accommodation_recommendation.py test_module2_rejection_eval.py -q
python test_module2_eval.py --out module2_eval_results.csv
```

Expected: focused tests pass; existing Module 2 evaluation completes without changing its reported day-cluster behavior.

### Task 4: Parse the optional response and render Google Maps hotel links

**Files:**
- Modify: `frontend/lib/features/planner/data/models/trip_plan_response.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_result_page.dart`
- Modify: `frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_budget_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_interest_page.dart`
- Create: `frontend/lib/features/planner/presentation/widgets/accommodation_recommendation_card.dart`
- Test: `frontend/test/features/planner/data/trip_plan_response_accommodation_test.dart`
- Test: `frontend/test/features/planner/presentation/accommodation_recommendation_card_test.dart`
- Modify: `frontend/test/features/planner/presentation/widgets/trip_result_loader_test.dart`
- Modify: `frontend/test/features/planner/presentation/trip_generation_loading_test.dart`

**Interfaces:**
- Add `AccommodationRecommendation? accommodationRecommendation` to `TripPlanResponse`.
- Add immutable models for recommendation, zone, and evaluation with null-safe parsing.
- `AccommodationRecommendationCard` receives the parsed model and an injectable `Future<bool> Function(Uri)` opener so widget tests do not launch external applications.
- Generation routes pass the fresh response as loader draft even when an `idPlan` exists; the loader preserves that recommendation if the saved-plan response does not contain it.

- [ ] **Step 1: Write failing parser and widget tests.**

```dart
test('parses one accommodation zone and evaluation thresholds', () {
  final plan = TripPlanResponse.fromJson(_responseWithRecommendation());
  expect(plan.accommodationRecommendation!.zones.single.dayFrom, 1);
  expect(plan.accommodationRecommendation!.zones.single.latitude, 21.0285);
  expect(plan.accommodationRecommendation!.evaluation.minZoneSeparationKm, 50.0);
});

testWidgets('renders a Google Maps action for each accommodation zone', (tester) async {
  await tester.pumpWidget(_hostWithRecommendation());
  expect(find.text('Find hotels on Google Maps'), findsNWidgets(2));
});
```

- [ ] **Step 2: Run the focused Flutter tests and confirm they fail because the model/card are absent.**

Run from `frontend`:

```powershell
flutter test test/features/planner/data/trip_plan_response_accommodation_test.dart test/features/planner/presentation/accommodation_recommendation_card_test.dart
```

- [ ] **Step 3: Implement null-safe response models and the result-page card.**

The card must show:

- one heading for the accommodation recommendation;
- each zone's day range;
- a short explanation based on `strategy` and `reductionRatio`;
- one coordinate-based Google Maps hotel-search button per zone.

The query must be generated from `latitude` and `longitude`, for example `hotels near 21.0285,105.8542`. When the optional field is missing or null, render no card and keep the existing itinerary page usable.

- [ ] **Step 4: Run the focused Flutter tests and existing planner tests.**

Run:

```powershell
flutter test test/features/planner/data/trip_plan_response_accommodation_test.dart test/features/planner/presentation/accommodation_recommendation_card_test.dart
flutter test test/features/planner
```

Expected: all focused and planner tests pass.

### Task 5: Verify the complete feature and inspect scope

**Files:**
- Modify only feature files from Tasks 1–4 if verification exposes a defect.

- [ ] **Step 1: Run Python syntax and focused backend tests.**

```powershell
python -m compileall services
python -m unittest test_accommodation_recommendation -v
```

- [ ] **Step 2: Run Flutter formatting and focused tests.**

```powershell
dart format lib/features/planner/data/models/trip_plan_response.dart lib/features/planner/presentation/trip_result_page.dart lib/features/planner/presentation/widgets/accommodation_recommendation_card.dart test/features/planner/data/trip_plan_response_accommodation_test.dart test/features/planner/presentation/accommodation_recommendation_card_test.dart
flutter test test/features/planner
```

If `dart format` or `flutter analyze` is blocked by a resident Dart analyzer process, record the environment limitation and rely on the focused/full Flutter test compilation plus `git diff --check` for this workspace verification.

- [ ] **Step 3: Confirm Module 3 source is unchanged and inspect the diff.**

```powershell
git diff --check
git diff -- cf_service/services/trip_planner.py
git status --short
```

Expected: any `trip_planner.py` diff contains only the top-level response field and no changes to `_derive_start_point`, `optimize_day_route`, or the `start_point` update loop. Existing unrelated working-tree changes remain unstaged.

- [ ] **Step 4: Run the final verification suite.**

```powershell
python -m unittest test_accommodation_recommendation -v
python test_module2_rejection_eval.py
flutter test test/features/planner
```

- [ ] **Step 5: Commit only the accommodation recommendation files.**

```powershell
git add cf_service/services/accommodation_recommendation.py cf_service/test_accommodation_recommendation.py cf_service/services/module2_algorithm.py cf_service/services/trip_planner.py frontend/lib/features/planner/data/models/trip_plan_response.dart frontend/lib/features/planner/presentation/trip_result_page.dart frontend/lib/features/planner/presentation/widgets/accommodation_recommendation_card.dart frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart frontend/lib/features/planner/presentation/trip_budget_page.dart frontend/lib/features/planner/presentation/trip_interest_page.dart frontend/test/features/planner/data/trip_plan_response_accommodation_test.dart frontend/test/features/planner/presentation/accommodation_recommendation_card_test.dart frontend/test/features/planner/presentation/widgets/trip_result_loader_test.dart frontend/test/features/planner/presentation/trip_generation_loading_test.dart docs/superpowers/plans/2026-08-06-accommodation-zone-recommendation.md
git commit -m "feat: recommend accommodation zones from itinerary"
```
