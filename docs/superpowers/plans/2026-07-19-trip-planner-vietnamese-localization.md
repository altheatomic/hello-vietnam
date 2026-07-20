# Trip Planner Vietnamese Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize every user-facing label, button, status, dialog action, and error in the complete Trip Planner flow when Vietnamese is selected while preserving the current English UI.

**Architecture:** Keep English strings as stable lookup keys and render them through the existing `AppStrings.ui` API. Add only missing Vietnamese mappings to the existing catalog, then update shared planner widgets and each planner screen to resolve text from `BuildContext` at render or action time.

**Tech Stack:** Flutter, Dart, `AppLanguageScope`, `AppStrings`, `flutter_test`

## Global Constraints

- Preserve English labels and behavior in English mode.
- Do not hardcode Vietnamese strings inside Trip Planner presentation widgets.
- Do not change navigation, trip generation, saving, forum sharing, maps, persistence, or visual layout.
- Preserve all pre-existing uncommitted changes, especially in `frontend/lib/core/language/app_language.dart` and its tests.
- Use failing tests before production changes and verify each red-green cycle.

---

### Task 1: Complete the Trip Planner translation catalog

**Files:**
- Create: `frontend/test/core/language/app_language_trip_planner_flow_test.dart`
- Modify: `frontend/lib/core/language/app_language.dart`

**Interfaces:**
- Consumes: `AppStrings.of(AppLanguage)` and `AppStrings.ui(String english)`.
- Produces: Vietnamese mappings for every static Trip Planner UI key while preserving the English fallback contract.

- [ ] **Step 1: Write the failing catalog test**

Create a table-driven test that includes the complete action vocabulary and representative headings, statuses, dialogs, and failures:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const Map<String, String> expectedVietnamese = <String, String>{
    'Back': 'Quay lại',
    'Next': 'Tiếp tục',
    'Generate': 'Tạo lịch trình',
    'Generating...': 'Đang tạo lịch trình...',
    'Save': 'Lưu',
    'Saving…': 'Đang lưu…',
    'Share': 'Chia sẻ',
    'Cancel': 'Hủy',
    'Saved Trips': 'Chuyến đi đã lưu',
    'Get Directions': 'Chỉ đường',
    'Create Trip on Google Maps': 'Tạo chuyến đi trên Google Maps',
    'Open itinerary': 'Mở lịch trình',
    'Plan again': 'Lên lịch lại',
    'Share to Forum': 'Chia sẻ lên Diễn đàn',
    'Back to trip planner': 'Quay lại Lịch trình',
    'Trip saved!': 'Đã lưu chuyến đi!',
    'Shared to Forum!': 'Đã chia sẻ lên Diễn đàn!',
    'Could not generate your trip. Please try again.':
        'Không thể tạo lịch trình. Vui lòng thử lại.',
  };

  test('localizes the complete Trip Planner action vocabulary', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);
    expectedVietnamese.forEach((String english, String vietnamese) {
      expect(strings.ui(english), vietnamese, reason: english);
    });
  });

  test('preserves Trip Planner labels in English', () {
    final AppStrings strings = AppStrings.of(AppLanguage.english);
    for (final String english in expectedVietnamese.keys) {
      expect(strings.ui(english), english, reason: english);
    }
  });
}
```

Before finishing the test, extend the map with every literal discovered in these files: `trip_planner_page.dart`, `trip_location_page.dart`, `business_location_page.dart`, `trip_duration_page.dart`, `trip_interest_page.dart`, `trip_budget_page.dart`, `trip_result_page.dart`, `trip_day_detail_page.dart`, `trip_map_page.dart`, `saved_trips_page.dart`, `planner_step_scaffold.dart`, `trip_result_loader.dart`, and `date_range_calendar.dart`.

- [ ] **Step 2: Run the catalog test and verify RED**

Run:

```bash
cd frontend
flutter test test/core/language/app_language_trip_planner_flow_test.dart
```

Expected: FAIL because at least `Generating...`, `Saving…`, `Share to Forum`, directions actions, and Trip Planner failure messages currently fall back to English.

- [ ] **Step 3: Add the minimal missing Vietnamese mappings**

Add entries to `AppStrings._viText` without reordering or rewriting unrelated existing entries. Use exact lookup keys from the UI, including punctuation and the Unicode ellipsis where present:

```dart
'Generating...': 'Đang tạo lịch trình...',
'Saving…': 'Đang lưu…',
'Share': 'Chia sẻ',
'Share to Forum': 'Chia sẻ lên Diễn đàn',
'Get Directions': 'Chỉ đường',
'Create Trip on Google Maps': 'Tạo chuyến đi trên Google Maps',
'Back to trip planner': 'Quay lại Lịch trình',
'Trip saved!': 'Đã lưu chuyến đi!',
'Shared to Forum!': 'Đã chia sẻ lên Diễn đàn!',
'Could not generate your trip. Please try again.':
    'Không thể tạo lịch trình. Vui lòng thử lại.',
```

Add exact translations for every other key asserted by the completed table-driven test.

- [ ] **Step 4: Run the catalog tests and verify GREEN**

Run:

```bash
cd frontend
flutter test test/core/language/app_language_trip_planner_flow_test.dart test/core/language/app_language_saved_trips_test.dart
```

Expected: PASS with no missing Vietnamese mappings and no regression in saved-trip translations.

- [ ] **Step 5: Commit the catalog contract**

```bash
git add frontend/lib/core/language/app_language.dart frontend/test/core/language/app_language_trip_planner_flow_test.dart
git commit -m "test: define Trip Planner Vietnamese copy"
```

Stage only the localization hunks created by this task if `app_language.dart` still contains unrelated user changes.

---

### Task 2: Localize shared wizard controls and trip setup screens

**Files:**
- Create: `frontend/test/features/planner/presentation/trip_planner_localization_test.dart`
- Modify: `frontend/lib/features/planner/presentation/widgets/planner_step_scaffold.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_planner_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_location_page.dart`
- Modify: `frontend/lib/features/planner/presentation/business_location_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_duration_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_interest_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_budget_page.dart`
- Modify: `frontend/lib/core/widgets/date_range_calendar.dart`

**Interfaces:**
- Consumes: `BuildContext.l10n`, `AppStrings.ui(String)`, `AppStrings.stepOf(int, int)`.
- Produces: A fully localized setup wizard that switches language through `AppLanguageScope` without altering callbacks or enabled states.

- [ ] **Step 1: Write failing widget tests for the shared controls and entry screen**

Initialize the storage singleton, build a small harness with `AppLanguageScope` and `MaterialApp`, then assert Vietnamese labels for `PlannerStepScaffold` and `TripPlannerPage`:

```dart
TestWidgetsFlutterBinding.ensureInitialized();

setUp(() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await LocalStorage.instance.initialize();
  await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
});

tearDown(() async {
  await AppLanguageController.instance.setLanguage(AppLanguage.english);
});

Widget vietnameseHarness(Widget child) {
  final AppLanguageController controller = AppLanguageController.instance;
  return AppLanguageScope(
    controller: controller,
    child: MaterialApp(home: child),
  );
}

testWidgets('planner wizard renders Vietnamese navigation controls',
    (WidgetTester tester) async {
  await tester.pumpWidget(vietnameseHarness(
    PlannerStepScaffold(
      currentStep: 2,
      badgeIcon: Icons.place_outlined,
      title: 'Where to?',
      subtitle: 'Choose your dream destination',
      onBack: () {},
      onNext: () {},
      nextEnabled: true,
      body: const SizedBox.shrink(),
    ),
  ));

  expect(find.text('Quay lại'), findsOneWidget);
  expect(find.text('Tiếp tục'), findsOneWidget);
  expect(find.text('Bước 2/5'), findsOneWidget);
  expect(find.text('Đi đâu?'), findsOneWidget);
});

testWidgets('trip type screen renders Vietnamese choices',
    (WidgetTester tester) async {
  await tester.pumpWidget(vietnameseHarness(const TripPlannerPage()));
  await tester.pumpAndSettle();

  expect(find.text('Loại chuyến đi'), findsOneWidget);
  expect(find.text('Du lịch'), findsOneWidget);
  expect(find.text('Công tác'), findsOneWidget);
  expect(find.text('Chuyến đi đã lưu'), findsOneWidget);
});
```

Import `shared_preferences.dart` and the app's `local_storage.dart`; restoring English in `tearDown` prevents singleton state from leaking to other tests.

- [ ] **Step 2: Run the widget tests and verify RED**

Run:

```bash
cd frontend
flutter test test/features/planner/presentation/trip_planner_localization_test.dart
```

Expected: FAIL because the shared controls and trip type screen currently render hardcoded English strings.

- [ ] **Step 3: Localize the shared scaffold and setup screens**

Import `core/language/app_language.dart` in each affected file. Resolve static copy at build time:

```dart
Text(context.l10n.ui('Personalized Itinerary'))
Text(context.l10n.ui("Let's create your perfect trip"))
Text(context.l10n.stepOf(currentStep, 5))
Text(context.l10n.ui('Back'))
Text(context.l10n.ui(label))
```

Pass localized titles and subtitles into private cards and fields:

```dart
_TripTypeCard(
  title: context.l10n.ui('Leisure Trip'),
  subtitle: context.l10n.ui('Relax, explore, and enjoy\nyour vacation'),
  // Existing icon, image, gradient, and callback remain unchanged.
)
```

For action-time messages, resolve them before showing the snack bar:

```dart
_showError(context.l10n.ui('Could not generate your trip. Please try again.'));
```

Translate every user-facing literal in the listed setup files, including search hints, empty states, field helper copy, choice labels, loading labels, budget presets, calendar headings/months/weekdays, and the Back/Next/Generate actions. Do not localize database values such as province names unless they already use catalog keys.

- [ ] **Step 4: Format and verify setup localization GREEN**

Run:

```bash
dart format frontend/lib/features/planner/presentation/widgets/planner_step_scaffold.dart frontend/lib/features/planner/presentation/trip_planner_page.dart frontend/lib/features/planner/presentation/trip_location_page.dart frontend/lib/features/planner/presentation/business_location_page.dart frontend/lib/features/planner/presentation/trip_duration_page.dart frontend/lib/features/planner/presentation/trip_interest_page.dart frontend/lib/features/planner/presentation/trip_budget_page.dart frontend/lib/core/widgets/date_range_calendar.dart frontend/test/features/planner/presentation/trip_planner_localization_test.dart
cd frontend
flutter test test/features/planner/presentation/trip_planner_localization_test.dart test/core/language/app_language_trip_planner_flow_test.dart
```

Expected: PASS; Vietnamese mode shows localized setup labels and English catalog behavior remains unchanged.

- [ ] **Step 5: Commit the setup flow**

```bash
git add frontend/lib/features/planner/presentation/widgets/planner_step_scaffold.dart frontend/lib/features/planner/presentation/trip_planner_page.dart frontend/lib/features/planner/presentation/trip_location_page.dart frontend/lib/features/planner/presentation/business_location_page.dart frontend/lib/features/planner/presentation/trip_duration_page.dart frontend/lib/features/planner/presentation/trip_interest_page.dart frontend/lib/features/planner/presentation/trip_budget_page.dart frontend/lib/core/widgets/date_range_calendar.dart frontend/test/features/planner/presentation/trip_planner_localization_test.dart
git commit -m "feat: localize Trip Planner setup flow"
```

---

### Task 3: Localize generated itinerary, directions, and loader states

**Files:**
- Create: `frontend/test/features/planner/presentation/trip_result_localization_test.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_result_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_day_detail_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_map_page.dart`
- Modify: `frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart`

**Interfaces:**
- Consumes: the Task 1 `AppStrings.ui` catalog and existing `TripPlanResponse`/`TripPlannerDayData` input models.
- Produces: Vietnamese result actions, summaries, dialogs, snack bars, map labels, and loading/error recovery controls.

- [ ] **Step 1: Write failing result-flow widget tests**

Pump the result page with a minimal in-memory plan and assert visible actions, then pump a day detail model and assert directions actions:

```dart
expect(find.text('Lưu'), findsOneWidget);
expect(find.text('Ngày'), findsWidgets);
expect(find.text('Hoạt động'), findsOneWidget);

expect(find.text('Tạo chuyến đi trên Google Maps'), findsOneWidget);
expect(find.text('Chỉ đường'), findsWidgets);
```

Add a dialog assertion by tapping the share action and expecting `Chia sẻ lên Diễn đàn`, `Hủy`, and `Chia sẻ`. Add loader-state assertions for `Quay lại` and `Quay lại Lịch trình` using the existing failure branches of `TripResultLoader`.

- [ ] **Step 2: Run the result tests and verify RED**

Run:

```bash
cd frontend
flutter test test/features/planner/presentation/trip_result_localization_test.dart
```

Expected: FAIL because result, sharing, directions, and loader actions currently render hardcoded English strings.

- [ ] **Step 3: Localize result, detail, map, and loader copy**

Import `app_language.dart` and resolve UI strings at the closest `BuildContext`:

```dart
label: context.l10n.ui(_isSaving ? 'Saving…' : 'Save')
```

```dart
title: Text(context.l10n.ui('Share to Forum')),
actions: <Widget>[
  TextButton(
    onPressed: () => Navigator.pop(ctx),
    child: Text(context.l10n.ui('Cancel')),
  ),
  TextButton(
    onPressed: _sharePlan,
    child: Text(context.l10n.ui('Share')),
  ),
],
```

Apply the same pattern to Days, Activities, Schedule, lunch/place fallbacks, save/share statuses, sign-in and retry failures, route creation, Get Directions, nearby-place labels, map origin/destination copy, open-in-maps controls, and result-loader error buttons. Localize mock fallback labels only at render time so stored/API model data remains unchanged.

- [ ] **Step 4: Format and verify result localization GREEN**

Run:

```bash
dart format frontend/lib/features/planner/presentation/trip_result_page.dart frontend/lib/features/planner/presentation/trip_day_detail_page.dart frontend/lib/features/planner/presentation/trip_map_page.dart frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart frontend/test/features/planner/presentation/trip_result_localization_test.dart
cd frontend
flutter test test/features/planner/presentation/trip_result_localization_test.dart test/core/language/app_language_trip_planner_flow_test.dart
```

Expected: PASS with Vietnamese actions throughout result, detail, maps, and recovery states.

- [ ] **Step 5: Commit the result flow**

```bash
git add frontend/lib/features/planner/presentation/trip_result_page.dart frontend/lib/features/planner/presentation/trip_day_detail_page.dart frontend/lib/features/planner/presentation/trip_map_page.dart frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart frontend/test/features/planner/presentation/trip_result_localization_test.dart
git commit -m "feat: localize Trip Planner result flow"
```

---

### Task 4: Localize saved trips and verify the complete flow

**Files:**
- Modify: `frontend/test/core/language/app_language_saved_trips_test.dart`
- Create: `frontend/test/features/planner/presentation/saved_trips_localization_test.dart`
- Modify: `frontend/lib/features/planner/presentation/saved_trips_page.dart`

**Interfaces:**
- Consumes: localized catalog entries and existing `TripStore` saved-trip models.
- Produces: Vietnamese saved-trip headers, filters, progress actions, empty state, notifications, reopen and replan controls.

- [ ] **Step 1: Extend failing saved-trip localization tests**

Add catalog expectations for all filter/action labels and a widget test with saved-trip data that asserts:

```dart
expect(find.text('Chuyến đi đã lưu'), findsOneWidget);
expect(find.text('Tất cả'), findsOneWidget);
expect(find.text('Sắp đi'), findsOneWidget);
expect(find.text('Đang đi'), findsOneWidget);
expect(find.text('Hoàn thành'), findsOneWidget);
expect(find.text('Mở lịch trình'), findsWidgets);
expect(find.text('Lên lịch lại'), findsWidgets);
```

Add an empty-filter assertion for `Chưa có chuyến đi nào khớp bộ lọc này.` and its localized create-new-itinerary action.

- [ ] **Step 2: Run saved-trip tests and verify RED**

Run:

```bash
cd frontend
flutter test test/core/language/app_language_saved_trips_test.dart test/features/planner/presentation/saved_trips_localization_test.dart
```

Expected: FAIL because `saved_trips_page.dart` passes untranslated model labels directly to UI widgets.

- [ ] **Step 3: Localize saved-trip presentation**

Resolve static and model-backed display labels at render time:

```dart
Text(context.l10n.ui(filter.label))
```

```dart
_SavedTripActionButton(
  label: context.l10n.ui('Open itinerary'),
  onTap: onOpenPlan,
)
```

Use typed helpers for dynamic progress copy:

```dart
context.l10n.savedTripCompletedCount(completed, total)
context.l10n.savedTripRemainingPlaces(remaining)
context.l10n.savedTripUpdated(context.l10n.ui(trip.title))
```

Translate header, counts, filters, generated fallback titles, dates where catalog mappings exist, status chips, completion copy, toggles, open/replan controls, empty-state copy, and feedback snack bars. Keep identifiers, plan IDs, and stored custom titles untouched.

- [ ] **Step 4: Run formatter, focused tests, full planner tests, and analyzer**

Run:

```bash
dart format frontend/lib/features/planner/presentation/saved_trips_page.dart frontend/test/core/language/app_language_saved_trips_test.dart frontend/test/features/planner/presentation/saved_trips_localization_test.dart
cd frontend
flutter test test/core/language/app_language_trip_planner_flow_test.dart test/core/language/app_language_saved_trips_test.dart test/features/planner/presentation/trip_planner_localization_test.dart test/features/planner/presentation/trip_result_localization_test.dart test/features/planner/presentation/saved_trips_localization_test.dart test/features/planner/data/trip_repository_test.dart
flutter analyze
```

Expected: all focused tests PASS and `flutter analyze` reports no new issues.

- [ ] **Step 5: Audit remaining raw Trip Planner literals**

Run:

```bash
rg -n "const Text\('[A-Za-z]|Text\('[A-Za-z]|label: '[A-Za-z]|hintText: '[A-Za-z]|buttonLabel: '[A-Za-z]" frontend/lib/features/planner frontend/lib/core/widgets/date_range_calendar.dart
```

Expected: any remaining matches are non-user-facing data constants or are immediately passed through `context.l10n.ui`; no actionable English UI literal bypasses localization.

- [ ] **Step 6: Commit saved trips and final verification**

```bash
git add frontend/lib/features/planner/presentation/saved_trips_page.dart frontend/test/core/language/app_language_saved_trips_test.dart frontend/test/features/planner/presentation/saved_trips_localization_test.dart
git commit -m "feat: complete Trip Planner Vietnamese localization"
```

Do not stage unrelated pre-existing changes.
