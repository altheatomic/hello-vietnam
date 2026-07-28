# Vietnam Journey Loading Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Vietnamese cloud-and-crane loading transition and use it for application bootstrap, trip-result loading, and trip generation.

**Architecture:** A focused `VietnamJourneyLoadingScreen` owns only presentation and delegates timing to a testable `JourneyLoadingTimeline`. Async owners pass `isComplete` and wait for `onExitComplete`; repository and navigation behavior remain outside the animation. Original transparent cloud and crane assets are rendered as layered images and animated with Flutter transform/opacity controllers.

**Tech Stack:** Flutter/Dart, `AnimationController`, widget tests, generated transparent PNG assets, existing `AppLanguage` localization.

## Global Constraints

- Minimum full-screen loader duration is exactly 3.2 seconds.
- The sequence is cloud-covered → cloud reveal → crane entrance → waiting → crane exit.
- Completion before 3.2 seconds is remembered; completion after 3.2 seconds exits immediately.
- Errors bypass the success exit and preserve current retry/error behavior.
- `MediaQuery.disableAnimations` uses short opacity/translation transitions.
- Animate transforms and opacity, not layout dimensions.
- No new runtime package or animation dependency.
- English and Vietnamese loading messages are required.

---

## File Structure

**Create**

- `frontend/lib/core/widgets/journey_loading/journey_loading_timeline.dart` — deterministic phase state machine.
- `frontend/lib/core/widgets/journey_loading/vietnam_journey_loading_screen.dart` — public loader composition and animation lifecycle.
- `frontend/lib/core/widgets/journey_loading/cloud_curtain.dart` — layered cloud rendering.
- `frontend/lib/core/widgets/journey_loading/flying_crane_flock.dart` — crane entrance, hover, and exit rendering.
- `frontend/assets/images/loading/vietnam_cloud_left.png` — transparent left cloud layer.
- `frontend/assets/images/loading/vietnam_cloud_right.png` — transparent right cloud layer.
- `frontend/assets/images/loading/vietnam_cloud_back.png` — transparent parallax cloud layer.
- `frontend/assets/images/loading/vietnam_crane_flock.png` — transparent original crane flock.
- `frontend/test/core/widgets/journey_loading/journey_loading_timeline_test.dart`
- `frontend/test/core/widgets/journey_loading/vietnam_journey_loading_screen_test.dart`
- `frontend/test/app/app_bootstrap_loading_test.dart`
- `frontend/test/features/planner/presentation/widgets/trip_result_loader_test.dart`
- `frontend/test/features/planner/presentation/trip_generation_loading_test.dart`

**Modify**

- `frontend/pubspec.yaml` — register loading assets.
- `frontend/lib/core/language/app_language.dart` — add Vietnamese loading copy.
- `frontend/lib/core/widgets/app_loading_screen.dart` — delegate full-screen mode to the journey loader and preserve compact mode.
- `frontend/lib/app/app_bootstrap.dart` — separate data readiness from animation exit.
- `frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart` — wait for exit before result reveal.
- `frontend/lib/features/planner/presentation/trip_budget_page.dart` — use the full-screen generation loader.
- `frontend/lib/features/planner/presentation/trip_interest_page.dart` — use the full-screen generation loader.

---

### Task 1: Loading timeline state machine

**Files:**

- Create: `frontend/lib/core/widgets/journey_loading/journey_loading_timeline.dart`
- Test: `frontend/test/core/widgets/journey_loading/journey_loading_timeline_test.dart`

**Interfaces:**

- Produces:
  - `enum JourneyLoadingPhase { covered, revealing, entering, waiting, exiting, complete }`
  - `class JourneyLoadingTimeline extends ChangeNotifier`
  - `JourneyLoadingTimeline({Duration minimumDuration = const Duration(milliseconds: 3200), Duration exitDuration = const Duration(milliseconds: 600)})`
  - `void start()`
  - `void markComplete()`
  - `JourneyLoadingPhase get phase`
  - `bool get completionRequested`
  - `Future<void> get finished`

- [ ] **Step 1: Write failing unit tests**

```dart
test('early completion waits for the 3.2 second minimum', () {
  fakeAsync((async) {
    final timeline = JourneyLoadingTimeline()..start();
    timeline.markComplete();
    async.elapse(const Duration(milliseconds: 3199));
    expect(timeline.phase, isNot(JourneyLoadingPhase.exiting));
    async.elapse(const Duration(milliseconds: 1));
    expect(timeline.phase, JourneyLoadingPhase.exiting);
  });
});

test('late completion exits immediately', () {
  fakeAsync((async) {
    final timeline = JourneyLoadingTimeline()..start();
    async.elapse(const Duration(seconds: 5));
    expect(timeline.phase, JourneyLoadingPhase.waiting);
    timeline.markComplete();
    expect(timeline.phase, JourneyLoadingPhase.exiting);
  });
});

test('finished completes once after the exit duration', () {
  fakeAsync((async) {
    final timeline = JourneyLoadingTimeline()..start();
    timeline.markComplete();
    async.elapse(const Duration(milliseconds: 3800));
    expect(timeline.phase, JourneyLoadingPhase.complete);
  });
});
```

- [ ] **Step 2: Run tests and confirm RED**

Run:

```bash
cd frontend
flutter test test/core/widgets/journey_loading/journey_loading_timeline_test.dart
```

Expected: compilation failure because `JourneyLoadingTimeline` does not exist.

- [ ] **Step 3: Implement the minimal timeline**

Use cancelable `Timer` fields for the phase boundaries at 300ms, 1200ms,
2100ms, 3200ms, and the 600ms exit. `markComplete()` sets
`completionRequested`; it enters `exiting` only after the 3200ms boundary.
Complete a private `Completer<void>` exactly once after exit.

- [ ] **Step 4: Verify GREEN**

Run the Task 1 test command. Expected: all timeline tests pass with no pending
timers after `dispose()`.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/core/widgets/journey_loading/journey_loading_timeline.dart frontend/test/core/widgets/journey_loading/journey_loading_timeline_test.dart
git commit -m "feat: add journey loading timeline"
```

---

### Task 2: Original loading assets and reusable animated screen

**Files:**

- Create: `frontend/lib/core/widgets/journey_loading/cloud_curtain.dart`
- Create: `frontend/lib/core/widgets/journey_loading/flying_crane_flock.dart`
- Create: `frontend/lib/core/widgets/journey_loading/vietnam_journey_loading_screen.dart`
- Create: `frontend/assets/images/loading/vietnam_cloud_left.png`
- Create: `frontend/assets/images/loading/vietnam_cloud_right.png`
- Create: `frontend/assets/images/loading/vietnam_cloud_back.png`
- Create: `frontend/assets/images/loading/vietnam_crane_flock.png`
- Modify: `frontend/pubspec.yaml`
- Test: `frontend/test/core/widgets/journey_loading/vietnam_journey_loading_screen_test.dart`

**Interfaces:**

- Consumes: `JourneyLoadingTimeline`.
- Produces:

```dart
class VietnamJourneyLoadingScreen extends StatefulWidget {
  const VietnamJourneyLoadingScreen({
    super.key,
    required this.message,
    this.isComplete = false,
    this.onExitComplete,
    this.compact = false,
    this.timelineFactory,
  });

  final String message;
  final bool isComplete;
  final VoidCallback? onExitComplete;
  final bool compact;
  final JourneyLoadingTimeline Function()? timelineFactory;
}
```

- [ ] **Step 1: Write failing widget tests**

Test keys and observable behavior:

```dart
expect(find.byKey(const Key('journey-loading-screen')), findsOneWidget);
expect(find.byKey(const Key('journey-cloud-left')), findsOneWidget);
expect(find.byKey(const Key('journey-cloud-right')), findsOneWidget);
expect(find.byKey(const Key('journey-crane-flock')), findsOneWidget);
expect(find.text('Opening Hello Vietnam'), findsOneWidget);
```

Add a fake timeline with short durations, pump `isComplete: true`, and assert
`onExitComplete` is called once. Add a `MediaQuery(disableAnimations: true)`
case and assert `journey-loading-reduced-motion` exists.

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd frontend
flutter test test/core/widgets/journey_loading/vietnam_journey_loading_screen_test.dart
```

Expected: compilation failure because the screen and child widgets do not
exist.

- [ ] **Step 3: Generate project-original assets**

Use the two supplied images only as mood/reference:

- generate original Vietnamese-inspired turquoise cloud motifs on a flat
  `#ff00ff` chroma background;
- generate an original flock of four ivory cranes with dark-blue outlines on
  the same chroma background;
- do not reproduce the reference composition, map, castle, text, or watermark;
- remove chroma with the imagegen helper;
- validate RGBA mode, transparent corners, and visible subject bounds;
- save only the final transparent PNGs under
  `frontend/assets/images/loading/`.

Register:

```yaml
flutter:
  assets:
    - assets/images/loading/
```

- [ ] **Step 4: Implement focused visual widgets**

`CloudCurtain` accepts `JourneyLoadingPhase phase` and `bool reduceMotion`.
Use `AnimatedSlide`/`AnimatedOpacity` with distinct distances for foreground
and back layers. `FlyingCraneFlock` accepts the same values and uses
`AnimatedSlide`, `AnimatedScale`, and a subtle bounded hover animation only in
`waiting`.

`VietnamJourneyLoadingScreen` owns the timeline, maps phases to child widgets,
calls `markComplete()` when `isComplete` changes, and calls
`onExitComplete` after `timeline.finished`. Decorative images use
`excludeFromSemantics: true`; wrap the message in a live-region `Semantics`.

- [ ] **Step 5: Verify GREEN and render safety**

```bash
cd frontend
flutter test test/core/widgets/journey_loading/vietnam_journey_loading_screen_test.dart
flutter analyze
```

Expected: tests pass, no overflow exceptions, analyzer clean.

- [ ] **Step 6: Commit**

```bash
git add frontend/assets/images/loading frontend/pubspec.yaml frontend/lib/core/widgets/journey_loading frontend/test/core/widgets/journey_loading
git commit -m "feat: build animated Vietnam journey loader"
```

---

### Task 3: App loading wrapper and localization

**Files:**

- Modify: `frontend/lib/core/widgets/app_loading_screen.dart`
- Modify: `frontend/lib/core/language/app_language.dart`
- Test: `frontend/test/core/widgets/app_loading_screen_test.dart`

**Interfaces:**

- Consumes: `VietnamJourneyLoadingScreen`.
- Extends `AppLoadingScreen` with:

```dart
final bool isComplete;
final VoidCallback? onExitComplete;
```

- [ ] **Step 1: Write failing tests**

Assert non-compact mode contains `VietnamJourneyLoadingScreen`, compact mode
does not contain cloud/crane asset keys, and Vietnamese lookup returns:

```dart
expect(
  AppStrings.of(AppLanguage.vietnamese).ui('Opening Hello Vietnam'),
  'Đang mở Hello Vietnam',
);
expect(
  AppStrings.of(AppLanguage.vietnamese).ui(
    'Preparing your Vietnam journey',
  ),
  'Đang chuẩn bị hành trình Việt Nam',
);
```

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd frontend
flutter test test/core/widgets/app_loading_screen_test.dart
```

Expected: non-compact loader lacks `VietnamJourneyLoadingScreen` and
translations return English.

- [ ] **Step 3: Implement wrapper and copy**

Keep the existing compact panel unchanged. Replace only the full-screen branch
with `VietnamJourneyLoadingScreen`, forwarding `message`, `isComplete`, and
`onExitComplete`. Add the three approved English/Vietnamese pairs to
`AppStrings._viUi`.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/core/widgets/app_loading_screen_test.dart
git add frontend/lib/core/widgets/app_loading_screen.dart frontend/lib/core/language/app_language.dart frontend/test/core/widgets/app_loading_screen_test.dart
git commit -m "feat: localize animated app loading screen"
```

---

### Task 4: Bootstrap integration

**Files:**

- Modify: `frontend/lib/app/app_bootstrap.dart`
- Test: `frontend/test/app/app_bootstrap_loading_test.dart`

**Interfaces:**

Add injectable defaults without changing production callers:

```dart
typedef AppInitializer = Future<void> Function();

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.initializeApp,
    this.readyBuilder,
  });

  final AppInitializer? initializeApp;
  final WidgetBuilder? readyBuilder;
}
```

- [ ] **Step 1: Write failing bootstrap tests**

Use a `Completer<void>` initializer. Assert:

- the animated loader is visible before completion;
- completing initialization sets loader `isComplete` but does not immediately
  render `readyBuilder`;
- firing the injected short timeline exit renders `readyBuilder`;
- initializer failure shows `Unable to start the app` without waiting for the
  success exit.

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd frontend
flutter test test/app/app_bootstrap_loading_test.dart
```

Expected: constructor does not accept injected initializer/builder.

- [ ] **Step 3: Extract and integrate**

Move the current `_initialize` body into `_initializeProductionApp()`. Track:

```dart
bool _dataReady = false;
bool _animationExited = false;
```

Render `readyBuilder?.call(context) ?? const MobileApp()` only when both are
true. When initialization succeeds, set `_dataReady = true`; pass it as
`isComplete` and set `_animationExited = true` from `onExitComplete`.
Preserve current retry behavior and reset both flags on retry.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/app/app_bootstrap_loading_test.dart
flutter test test/widget_test.dart
git add frontend/lib/app/app_bootstrap.dart frontend/test/app/app_bootstrap_loading_test.dart
git commit -m "feat: animate application bootstrap transition"
```

---

### Task 5: Trip result loading integration

**Files:**

- Modify: `frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart`
- Test: `frontend/test/features/planner/presentation/widgets/trip_result_loader_test.dart`

**Interfaces:**

Inject plan loading:

```dart
typedef TripPlanLoader = Future<TripPlanResponse> Function(String idPlan);

final TripPlanLoader? loadPlan;
```

Track `_loadedPlan` separately from `_showResult`. The result is shown only
after the loader exit callback.

- [ ] **Step 1: Write failing tests**

With a `Completer<TripPlanResponse>`:

- assert the journey loader while pending;
- complete successfully and assert the result is not shown before exit;
- trigger short-timeline exit and assert the result appears;
- complete with error and assert the existing error view appears without a
  success exit.

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd frontend
flutter test test/features/planner/presentation/widgets/trip_result_loader_test.dart
```

Expected: `loadPlan` injection and animated loader are absent.

- [ ] **Step 3: Implement integration**

Use `widget.loadPlan?.call(idPlan) ?? TripRepository().getPlan(idPlan)`.
While loading or waiting for exit, render:

```dart
VietnamJourneyLoadingScreen(
  message: context.l10n.ui('Preparing your Vietnam journey'),
  isComplete: _loadedPlan != null,
  onExitComplete: () => setState(() => _showResult = true),
)
```

On error, immediately render `_TripResultMessageView`.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/features/planner/presentation/widgets/trip_result_loader_test.dart
git add frontend/lib/features/planner/presentation/widgets/trip_result_loader.dart frontend/test/features/planner/presentation/widgets/trip_result_loader_test.dart
git commit -m "feat: animate trip result loading"
```

---

### Task 6: Planner generation integration

**Files:**

- Modify: `frontend/lib/features/planner/presentation/trip_budget_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_interest_page.dart`
- Test: `frontend/test/features/planner/presentation/trip_generation_loading_test.dart`

**Interfaces:**

Add to both pages:

```dart
final Future<TripPlanResponse> Function(TripPlanRequest request)? generateTrip;
```

Store a successful response in `_pendingResponse`; navigate only from
`_finishGenerationTransition`.

- [ ] **Step 1: Write failing tests**

For each page:

- make a valid selection and tap Generate;
- assert `VietnamJourneyLoadingScreen` replaces the planner content;
- complete the injected generator and assert navigation has not occurred before
  exit;
- trigger exit and assert the correct result route/extra;
- fail the generator and assert the loader disappears and the existing
  localized SnackBar appears.

- [ ] **Step 2: Run tests and confirm RED**

```bash
cd frontend
flutter test test/features/planner/presentation/trip_generation_loading_test.dart
```

Expected: constructor lacks `generateTrip` and pages show `_LoadingBanner`.

- [ ] **Step 3: Implement one shared behavior in both pages**

Replace `_LoadingBanner` with an early full-screen build branch:

```dart
if (_isLoading) {
  return VietnamJourneyLoadingScreen(
    message: context.l10n.ui(
      'Generating your personalised itinerary…',
    ),
    isComplete: _pendingResponse != null,
    onExitComplete: _finishGenerationTransition,
  );
}
```

Use the injected callback or `TripRepository().planTrip`. On success, store the
response and wait. On error, clear `_isLoading` immediately and show the
existing error. Remove both private `_LoadingBanner` classes after tests pass.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/features/planner/presentation/trip_generation_loading_test.dart
flutter test test/features/planner
git add frontend/lib/features/planner/presentation/trip_budget_page.dart frontend/lib/features/planner/presentation/trip_interest_page.dart frontend/test/features/planner/presentation/trip_generation_loading_test.dart
git commit -m "feat: animate trip generation loading"
```

---

### Task 7: Full verification

**Files:** No production changes unless verification reveals a regression.

- [ ] **Step 1: Format changed Dart files**

```bash
cd frontend
dart format lib/core/widgets/journey_loading lib/core/widgets/app_loading_screen.dart lib/app/app_bootstrap.dart lib/features/planner/presentation test/core/widgets test/app/app_bootstrap_loading_test.dart test/features/planner/presentation
```

- [ ] **Step 2: Run focused suites**

```bash
flutter test test/core/widgets
flutter test test/app/app_bootstrap_loading_test.dart
flutter test test/features/planner
```

Expected: all tests pass.

- [ ] **Step 3: Run analyzer and diff checks**

```bash
flutter analyze
cd ..
git diff --check
git status --short
```

Expected: analyzer reports `No issues found`; diff check exits zero; status
contains only intended loading changes plus pre-existing user changes.

- [ ] **Step 4: Manual animation review**

Run the app on the configured device and verify:

- bootstrap clouds fully cover the first frame;
- clouds split without exposing a black frame;
- crane flock waits indefinitely when loading is delayed;
- success flies left before content appears;
- light/dark contrast and Vietnamese copy are readable;
- no animation restarts during rebuild;
- planner errors return control to the form.

- [ ] **Step 5: Final commit**

```bash
git add frontend
git commit -m "feat: add Vietnam journey loading experience"
```
