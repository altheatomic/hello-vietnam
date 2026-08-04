# Nearby Lunch Restaurants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show exactly one nearby-restaurant action in every non-empty detailed itinerary day, positioned after the selected pre-lunch place and opening a Google Maps restaurant search around that place.

**Architecture:** Preserve each place's end time in the existing presentation model, select the lunch anchor with a pure deterministic utility, and compose a focused lunch-discovery card into the detailed-day activity list. Keep Google Maps URL construction and external launching in `maps_launcher.dart`; inject the launcher into the page for widget testing. No backend, database, Google Places API, or itinerary-generation changes are required.

**Tech Stack:** Flutter 3.38.9+, Dart 3.10.8+, Material, `url_launcher` 6.3.2, `flutter_test`.

## Global Constraints

- The feature appears only in the detailed itinerary day screen; the itinerary summary remains unchanged.
- Use the inclusive lunch window `11:30-13:00`.
- Show exactly one card for every non-empty day, whether zero, one, or multiple synthetic `lunch_break` entries exist.
- Search all nearby restaurants; do not filter by cuisine or user preferences.
- Use a universal Google Maps URL and do not add an API key, dependency, backend request, database migration, or Google Places API integration.
- Keep itinerary place order unchanged and do not count the discovery card as an activity.
- If no place starts before `13:00`, anchor the card after the first real place.
- Add English and Vietnamese strings through the existing `AppStrings.ui` mechanism.
- Preserve unrelated dirty-worktree changes and stage only files belonging to each task.

## File Structure

- Create `frontend/lib/features/planner/presentation/lunch_anchor_selector.dart`: parse itinerary clock values and select one real activity as the lunch anchor.
- Create `frontend/lib/features/planner/presentation/widgets/lunch_discovery_card.dart`: render the reusable lunch action card without selecting data or launching Maps.
- Modify `frontend/lib/features/planner/presentation/trip_planner_mock_data.dart`: preserve nullable activity `endTime` through construction and JSON serialization.
- Modify `frontend/lib/features/planner/presentation/trip_result_page.dart`: copy `TripPlanPlace.endTime` into `TripPlannerActivityData`.
- Modify `frontend/lib/core/utils/maps_launcher.dart`: validate coordinates, build the restaurant-search URI, and return external-launch success.
- Modify `frontend/lib/core/language/app_language.dart`: add the new Vietnamese translations.
- Modify `frontend/lib/features/planner/presentation/trip_day_detail_page.dart`: select the anchor, insert one card, invoke the injected launcher, and display failure feedback.
- Create focused tests under `frontend/test/features/planner/presentation/` and `frontend/test/core/utils/`.

---

### Task 1: Preserve activity end time

**Files:**
- Modify: `frontend/lib/features/planner/presentation/trip_planner_mock_data.dart:419`
- Modify: `frontend/lib/features/planner/presentation/trip_result_page.dart:341`
- Create: `frontend/test/features/planner/presentation/trip_planner_activity_data_test.dart`

**Interfaces:**
- Consumes: `TripPlanPlace.endTime` from the existing planning response model.
- Produces: `TripPlannerActivityData.endTime` as `String?`, serialized with key `endTime` and backward-compatible when absent.

- [ ] **Step 1: Write failing model serialization tests**

Create `trip_planner_activity_data_test.dart` with a local activity factory and these assertions:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

void main() {
  test('preserves nullable endTime through JSON', () {
    const activity = TripPlannerActivityData(
      title: 'Museum',
      time: '10:30',
      endTime: '11:45',
      slot: 'Morning',
      tag: 'culture',
      description: '',
      distanceLabel: '',
      tips: <String>[],
      nearbyPlaces: <TripPlannerNearbyPlace>[],
      lat: 16.07,
      lng: 108.22,
    );

    final restored = TripPlannerActivityData.fromJson(activity.toJson());

    expect(activity.toJson()['endTime'], '11:45');
    expect(restored.endTime, '11:45');
  });

  test('deserializes activity JSON created before endTime existed', () {
    final restored = TripPlannerActivityData.fromJson(<String, dynamic>{
      'title': 'Museum',
      'time': '10:30',
      'slot': 'Morning',
      'tag': 'culture',
      'description': '',
      'distanceLabel': '',
      'tips': <String>[],
      'nearbyPlaces': <Map<String, dynamic>>[],
      'lat': 16.07,
      'lng': 108.22,
      'imageUrl': null,
    });

    expect(restored.endTime, isNull);
  });
}
```

- [ ] **Step 2: Run the model test and verify it fails**

Run from `frontend`:

```powershell
flutter test test/features/planner/presentation/trip_planner_activity_data_test.dart
```

Expected: compilation fails because `endTime` is not defined.

- [ ] **Step 3: Add nullable end-time support to the presentation model**

Update the constructor, field, and JSON methods in `TripPlannerActivityData`:

```dart
const TripPlannerActivityData({
  required this.title,
  required this.time,
  this.endTime,
  // existing parameters remain unchanged
});

final String? endTime;

Map<String, dynamic> toJson() => <String, dynamic>{
  // existing keys remain unchanged
  'endTime': endTime,
};

factory TripPlannerActivityData.fromJson(Map<String, dynamic> json) =>
    TripPlannerActivityData(
      // existing fields remain unchanged
      endTime: json['endTime'] as String?,
    );
```

In both branches of `_convertPlan`, pass `endTime: p.endTime`. The selector still excludes synthetic lunch entries from anchor candidates.

- [ ] **Step 4: Run the focused test and existing planner serialization consumers**

```powershell
flutter test test/features/planner/presentation/trip_planner_activity_data_test.dart test/features/planner/presentation/planner_dark_mode_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit the model change**

```powershell
git add frontend/lib/features/planner/presentation/trip_planner_mock_data.dart frontend/lib/features/planner/presentation/trip_result_page.dart frontend/test/features/planner/presentation/trip_planner_activity_data_test.dart
git commit -m "feat: preserve itinerary activity end time"
```

---

### Task 2: Select the lunch anchor deterministically

**Files:**
- Create: `frontend/lib/features/planner/presentation/lunch_anchor_selector.dart`
- Create: `frontend/test/features/planner/presentation/lunch_anchor_selector_test.dart`

**Interfaces:**
- Consumes: `List<TripPlannerActivityData>` containing real places and possible `tag == 'lunch_break'` entries.
- Produces: `TripPlannerActivityData? selectLunchAnchor(List<TripPlannerActivityData> activities)`.

- [ ] **Step 1: Write failing selector tests for every priority branch**

Create a helper with unique titles and write tests that assert object identity:

```dart
TripPlannerActivityData place(
  String title, {
  required String start,
  String? end,
  String tag = 'culture',
}) => TripPlannerActivityData(
  title: title,
  time: start,
  endTime: end,
  slot: 'Morning',
  tag: tag,
  description: '',
  distanceLabel: '',
  tips: const <String>[],
  nearbyPlaces: const <TripPlannerNearbyPlace>[],
  lat: 16.0,
  lng: 108.0,
);
```

Required test cases:

```dart
test('chooses latest end inside inclusive lunch window', () {
  final atStart = place('A', start: '10:00', end: '11:30');
  final latest = place('B', start: '11:20', end: '13:00');
  final after = place('C', start: '12:30', end: '13:30');
  expect(selectLunchAnchor(<TripPlannerActivityData>[atStart, latest, after]), same(latest));
});

test('falls back to latest end before 11:30', () {
  final early = place('A', start: '08:00', end: '09:00');
  final latest = place('B', start: '10:00', end: '11:20');
  expect(selectLunchAnchor(<TripPlannerActivityData>[early, latest]), same(latest));
});

test('falls back to latest start before 13:00 when end times are unusable', () {
  final early = place('A', start: '09:00');
  final latest = place('B', start: '12:45', end: 'invalid');
  expect(selectLunchAnchor(<TripPlannerActivityData>[early, latest]), same(latest));
});

test('falls back to first real place when none starts before 13:00', () {
  final first = place('A', start: '13:00', end: '14:00');
  final second = place('B', start: '15:00', end: '16:00');
  expect(selectLunchAnchor(<TripPlannerActivityData>[first, second]), same(first));
});

test('ignores synthetic lunch breaks and returns null for no real place', () {
  final lunch = place('Lunch', start: '12:00', end: '13:00', tag: 'lunch_break');
  expect(selectLunchAnchor(<TripPlannerActivityData>[lunch, lunch]), isNull);
});
```

Also test `HH:mm:ss`, malformed values, and equal-time ties; equal times select the later place in itinerary order so insertion remains deterministic.

- [ ] **Step 2: Run the selector tests and verify they fail**

```powershell
flutter test test/features/planner/presentation/lunch_anchor_selector_test.dart
```

Expected: compilation fails because `selectLunchAnchor` does not exist.

- [ ] **Step 3: Implement the pure selector**

Implement time parsing without `BuildContext` or mutable state:

```dart
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

const int _lunchStartMinutes = 11 * 60 + 30;
const int _lunchEndMinutes = 13 * 60;

int? _parseClockMinutes(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

TripPlannerActivityData? selectLunchAnchor(
  List<TripPlannerActivityData> activities,
) {
  final places = activities.where((a) => a.tag != 'lunch_break').toList();
  if (places.isEmpty) return null;

  TripPlannerActivityData? latestMatching(
    int? Function(TripPlannerActivityData activity) minutesOf,
    bool Function(int minutes) accepts,
  ) {
    TripPlannerActivityData? best;
    var bestMinutes = -1;
    for (final place in places) {
      final minutes = minutesOf(place);
      if (minutes != null && accepts(minutes) && minutes >= bestMinutes) {
        best = place;
        bestMinutes = minutes;
      }
    }
    return best;
  }

  return latestMatching(
        (p) => _parseClockMinutes(p.endTime),
        (m) => m >= _lunchStartMinutes && m <= _lunchEndMinutes,
      ) ??
      latestMatching(
        (p) => _parseClockMinutes(p.endTime),
        (m) => m < _lunchStartMinutes,
      ) ??
      latestMatching(
        (p) => _parseClockMinutes(p.time),
        (m) => m < _lunchEndMinutes,
      ) ??
      places.first;
}
```

- [ ] **Step 4: Run selector and model tests**

```powershell
flutter test test/features/planner/presentation/lunch_anchor_selector_test.dart test/features/planner/presentation/trip_planner_activity_data_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit the selector**

```powershell
git add frontend/lib/features/planner/presentation/lunch_anchor_selector.dart frontend/test/features/planner/presentation/lunch_anchor_selector_test.dart
git commit -m "feat: select itinerary lunch anchor"
```

---

### Task 3: Build and launch the Google Maps restaurant search

**Files:**
- Modify: `frontend/lib/core/utils/maps_launcher.dart`
- Create: `frontend/test/core/utils/maps_launcher_test.dart`

**Interfaces:**
- Produces: `bool hasValidMapCoordinates({required double lat, required double lng})`.
- Produces: `Uri buildNearbyRestaurantsUri({required double lat, required double lng})`.
- Produces: `Future<bool> openNearbyRestaurants({required double lat, required double lng})`.

- [ ] **Step 1: Write failing URI and validation tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';

void main() {
  test('builds encoded universal Google Maps restaurant search URL', () {
    final uri = buildNearbyRestaurantsUri(lat: 16.0678, lng: 108.2208);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], 'restaurants near 16.0678,108.2208');
  });

  test('validates coordinate bounds and rejects placeholder coordinates', () {
    expect(hasValidMapCoordinates(lat: 16.0, lng: 108.0), isTrue);
    expect(hasValidMapCoordinates(lat: 0.0, lng: 0.0), isFalse);
    expect(hasValidMapCoordinates(lat: double.nan, lng: 108.0), isFalse);
    expect(hasValidMapCoordinates(lat: 91.0, lng: 108.0), isFalse);
    expect(hasValidMapCoordinates(lat: 16.0, lng: 181.0), isFalse);
  });

  test('URI builder rejects invalid coordinates', () {
    expect(
      () => buildNearbyRestaurantsUri(lat: 0.0, lng: 0.0),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run the Maps utility test and verify it fails**

```powershell
flutter test test/core/utils/maps_launcher_test.dart
```

Expected: compilation fails because the new functions are missing.

- [ ] **Step 3: Implement URI construction and safe launch**

Add to `maps_launcher.dart`:

```dart
bool hasValidMapCoordinates({required double lat, required double lng}) {
  return lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0.0 && lng == 0.0);
}

Uri buildNearbyRestaurantsUri({required double lat, required double lng}) {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) {
    throw ArgumentError.value(<double>[lat, lng], 'coordinates');
  }
  return Uri.https(
    'www.google.com',
    '/maps/search/',
    <String, String>{
      'api': '1',
      'query': 'restaurants near $lat,$lng',
    },
  );
}

Future<bool> openNearbyRestaurants({
  required double lat,
  required double lng,
}) async {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) return false;
  try {
    return await launchUrl(
      buildNearbyRestaurantsUri(lat: lat, lng: lng),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
```

Do not alter `openGoogleMapsPin` or `openGoogleMapsDirections` behavior.

- [ ] **Step 4: Run Maps utility tests**

```powershell
flutter test test/core/utils/maps_launcher_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit the Maps utility**

```powershell
git add frontend/lib/core/utils/maps_launcher.dart frontend/test/core/utils/maps_launcher_test.dart
git commit -m "feat: open nearby restaurants in Google Maps"
```

---

### Task 4: Render and localize the lunch discovery card

**Files:**
- Create: `frontend/lib/features/planner/presentation/widgets/lunch_discovery_card.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_day_detail_page.dart:23`
- Modify: `frontend/lib/core/language/app_language.dart:1037`
- Create: `frontend/test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart`
- Create: `frontend/test/core/language/app_language_nearby_lunch_test.dart`

**Interfaces:**
- Consumes: `selectLunchAnchor(...)`, `hasValidMapCoordinates(...)`, and `openNearbyRestaurants(...)` from Tasks 2 and 3.
- Produces: `LunchDiscoveryCard(anchorName, lunchWindow, enabled, onTap)` and an injectable `NearbyRestaurantsLauncher` on `TripDayDetailPage`.

- [ ] **Step 1: Write failing localization tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const expected = <String, String>{
    'What to eat nearby?': 'Ăn gì gần đây?',
    'Explore restaurants near': 'Khám phá quán ăn và nhà hàng quanh',
    'View restaurants on Google Maps': 'Xem quán ăn trên Google Maps',
    'Restaurant search is unavailable for this location.':
        'Không thể tìm quán ăn cho vị trí này.',
    'Could not open Google Maps. Please try again.':
        'Không thể mở Google Maps. Vui lòng thử lại.',
  };

  test('localizes nearby lunch discovery copy', () {
    final vi = AppStrings.of(AppLanguage.vietnamese);
    final en = AppStrings.of(AppLanguage.english);
    expected.forEach((english, vietnamese) {
      expect(vi.ui(english), vietnamese);
      expect(en.ui(english), english);
    });
  });
}
```

- [ ] **Step 2: Write failing detailed-day widget tests**

Build `TripPlannerDayData` with unique place titles and inject a fake launcher:

```dart
var launches = <({double lat, double lng})>[];
Future<bool> fakeLauncher({required double lat, required double lng}) async {
  launches.add((lat: lat, lng: lng));
  return true;
}
```

Cover these assertions:

```dart
expect(find.byKey(const Key('lunch-discovery-card')), findsOneWidget);

final cardTop = tester.getTopLeft(find.byKey(const Key('lunch-discovery-card'))).dy;
final anchorBottom = tester.getBottomLeft(find.text('Lunch Anchor')).dy;
final nextTop = tester.getTopLeft(find.text('Afternoon Place')).dy;
expect(cardTop, greaterThan(anchorBottom));
expect(cardTop, lessThan(nextTop));

await tester.tap(find.text('View restaurants on Google Maps'));
await tester.pump();
expect(launches.single, (lat: 16.07, lng: 108.22));
```

Also cover: multiple synthetic lunch entries still produce one card; no pre-13:00 activity inserts after the first real place; empty real-place day produces no card; a false launcher result displays `Could not open Google Maps. Please try again.`; invalid coordinates disable the action and show the unavailable explanation.

- [ ] **Step 3: Run localization and widget tests and verify they fail**

```powershell
flutter test test/core/language/app_language_nearby_lunch_test.dart test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart
```

Expected: tests fail because strings, card, injection, and list insertion do not exist.

- [ ] **Step 4: Add localized strings**

Add the exact English keys from Step 1 to the Vietnamese UI map in `app_language.dart`. Do not concatenate translated words inside the localization map; the page may compose the localized prefix and the dynamic anchor name at render time.

- [ ] **Step 5: Implement the focused lunch card widget**

Create `LunchDiscoveryCard` with this public shape:

```dart
class LunchDiscoveryCard extends StatelessWidget {
  const LunchDiscoveryCard({
    super.key,
    required this.anchorName,
    required this.lunchWindow,
    required this.enabled,
    required this.onTap,
  });

  final String anchorName;
  final String lunchWindow;
  final bool enabled;
  final VoidCallback onTap;
}
```

The root uses `key ?? const Key('lunch-discovery-card')`, a warm adaptive surface, rounded border, restaurant icon, localized title, `11:30-13:00`, localized supporting prefix plus `anchorName`, and a blue-gradient action. When disabled, prevent taps, lower opacity, and show the localized unavailable explanation.

- [ ] **Step 6: Insert exactly one card in the detailed-day list**

Add the injectable launcher:

```dart
typedef NearbyRestaurantsLauncher = Future<bool> Function({
  required double lat,
  required double lng,
});

class TripDayDetailPage extends StatelessWidget {
  const TripDayDetailPage({
    super.key,
    required this.dayIndex,
    this.dayData,
    this.nearbyRestaurantsLauncher = openNearbyRestaurants,
  });

  final NearbyRestaurantsLauncher nearbyRestaurantsLauncher;
}
```

Inside `build`, derive data once:

```dart
final realPlaces = day.activities
    .where((activity) => activity.tag != 'lunch_break')
    .toList();
final lunchAnchor = selectLunchAnchor(day.activities);
```

Replace the current filtered `.map(...)` with an indexed composition over `realPlaces`. After each `_ActivityDetailCard`, insert `LunchDiscoveryCard` only when `identical(activity, lunchAnchor)` is true. Use `hasValidMapCoordinates` for `enabled`.

On card tap, call the injected launcher with the anchor coordinates. If it returns false and `context.mounted`, display:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      context.l10n.ui('Could not open Google Maps. Please try again.'),
    ),
  ),
);
```

Keep `_openDayRoute` and all existing place-direction callbacks unchanged.

- [ ] **Step 7: Run focused UI and localization tests**

```powershell
flutter test test/core/language/app_language_nearby_lunch_test.dart test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart test/features/planner/presentation/planner_dark_mode_test.dart
```

Expected: all tests pass with no overflow or uncaught exception.

- [ ] **Step 8: Commit the detailed-day feature**

```powershell
git add frontend/lib/core/language/app_language.dart frontend/lib/features/planner/presentation/trip_day_detail_page.dart frontend/lib/features/planner/presentation/widgets/lunch_discovery_card.dart frontend/test/core/language/app_language_nearby_lunch_test.dart frontend/test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart
git commit -m "feat: add nearby lunch restaurant action"
```

---

### Task 5: Run feature and regression verification

**Files:**
- Verify only; modify a feature file or focused test only if a failure demonstrates a defect in Tasks 1-4.

**Interfaces:**
- Consumes: all interfaces produced by Tasks 1-4.
- Produces: verified nearby-lunch feature with no known targeted regression.

- [ ] **Step 1: Format changed Dart files**

Run from `frontend` with the explicit feature file list:

```powershell
dart format lib/core/utils/maps_launcher.dart lib/core/language/app_language.dart lib/features/planner/presentation/lunch_anchor_selector.dart lib/features/planner/presentation/trip_planner_mock_data.dart lib/features/planner/presentation/trip_result_page.dart lib/features/planner/presentation/trip_day_detail_page.dart lib/features/planner/presentation/widgets/lunch_discovery_card.dart test/core/utils/maps_launcher_test.dart test/core/language/app_language_nearby_lunch_test.dart test/features/planner/presentation/trip_planner_activity_data_test.dart test/features/planner/presentation/lunch_anchor_selector_test.dart test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart
```

- [ ] **Step 2: Run all nearby-lunch tests together**

```powershell
flutter test test/core/utils/maps_launcher_test.dart test/core/language/app_language_nearby_lunch_test.dart test/features/planner/presentation/trip_planner_activity_data_test.dart test/features/planner/presentation/lunch_anchor_selector_test.dart test/features/planner/presentation/trip_day_detail_lunch_discovery_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Run planner regression tests**

```powershell
flutter test test/features/planner
```

Expected: all planner tests pass.

- [ ] **Step 4: Run static analysis on the modified production files**

```powershell
flutter analyze lib/core/utils/maps_launcher.dart lib/core/language/app_language.dart lib/features/planner/presentation/lunch_anchor_selector.dart lib/features/planner/presentation/trip_planner_mock_data.dart lib/features/planner/presentation/trip_result_page.dart lib/features/planner/presentation/trip_day_detail_page.dart lib/features/planner/presentation/widgets/lunch_discovery_card.dart
```

Expected: no analyzer errors or warnings in the modified files.

- [ ] **Step 5: Review the final diff for scope and accidental changes**

```powershell
git diff --check
git status --short
```

Confirm that the feature changes only the files listed in this plan and that unrelated pre-existing worktree changes remain untouched.

- [ ] **Step 6: Commit formatting or verification fixes if needed**

If Step 1 or a verified defect required changes, stage only the affected files from this plan and commit them:

```powershell
git commit -m "test: verify nearby lunch restaurant flow"
```

If verification produced no file changes, do not create an empty commit.
