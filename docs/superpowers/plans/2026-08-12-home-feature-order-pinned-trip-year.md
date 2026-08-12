# Home Feature Order and Pinned Trip Year Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Reorder the Home quick-action grid and keep the Trip Planner year navigation pinned while the date-selection content scrolls for both Leisure and Business trips.

**Architecture:** Keep homeFeatures as the Home grid's single source of truth and reorder only its existing entries. Extract the calendar's year controls into a reusable DateRangeYearNavigation, add an optional externally controlled visible year to DateRangeCalendar, and let TripDurationPage place the year controls into the existing PlannerStepScaffold.stickyBodyHeader while the calendar renders only the scrolling body.

**Tech Stack:** Flutter/Dart, Material widgets, CustomScrollView, SliverPersistentHeader, Flutter widget tests, flutter analyze.

## Global Constraints

- Home quick-action order must be exactly Recommend, Explore, Trip Planner, Forum, Translate, AI Search, Send Report, Popular Apps.
- The Home grid remains four columns and row-major; no feature, route, icon, localization, or saved-trip badge behavior changes.
- Only the year navigation row is pinned; the range summary, 1-Day Trip toggle, and month cards remain scrollable.
- Leisure and Business both use the shared TripDurationPage and must receive the same pinned-year behavior.
- DateRangeCalendar callers that do not opt into external year control retain the current internal year navigation and scrolling behavior.
- Date selection, minimum-date validation, one-day mode, range calculation, and localization remain unchanged.
- No backend, database, route, deployment, network, or storage changes are in scope.
- Write each regression test before its implementation and run it once in the failing state.
- Use mocked/local widget tests only; do not make network or Supabase requests.

## File Map

- Modify frontend/lib/features/home/data/home_feature_data.dart to reorder the existing eight FeatureItem entries.
- Modify frontend/test/features/home/data/home_feature_data_test.dart to lock the requested row-major order and existing route contracts.
- Modify frontend/lib/core/widgets/date_range_calendar.dart to expose the year-navigation widget, accept an optional controlled year, hide the internal row when requested, and preserve existing default behavior.
- Modify frontend/test/core/widgets/date_range_calendar_test.dart to cover the controlled-year API and preserved selection state.
- Modify frontend/lib/features/planner/presentation/trip_duration_page.dart to own the visible year and compose the pinned header with the shared calendar.
- Create frontend/test/features/planner/presentation/trip_duration_page_test.dart to verify pinned behavior for Leisure and Business.
- Modify frontend/lib/features/planner/presentation/widgets/planner_step_scaffold.dart so the sticky delegate's painted child exactly fills its declared extent.
- Keep frontend/lib/features/recommend/presentation/when/recommend_when_calendar_page.dart and frontend/lib/features/planner/presentation/widgets/start_date_picker_sheet.dart on the default DateRangeCalendar API so their internal year controls remain unchanged.

### Task 1: Reorder the Home Quick Actions

**Files:**
- Modify: frontend/lib/features/home/data/home_feature_data.dart:6-47
- Modify: frontend/test/features/home/data/home_feature_data_test.dart:7-44

**Interfaces:**
- Consumes: the existing FeatureItem constants and AppRoutes values.
- Produces: homeFeatures with the same eight entries in the requested order for FeatureGrid.

- [x] Step 1: Write the failing order regression test

Add this test to frontend/test/features/home/data/home_feature_data_test.dart:

    test('home quick actions use the requested row-major order', () {
      expect(
        homeFeatures.map((FeatureItem item) => item.title).toList(),
        <String>[
          'Recommend',
          'Explore',
          'Trip Planner',
          'Forum',
          'Translate',
          'AI Search',
          'Send\nReport',
          'Popular\nApps',
        ],
      );
      expect(
        homeFeatures.map((FeatureItem item) => item.route).toList(),
        <String>[
          AppRoutes.recommendWhereSearch,
          AppRoutes.explore,
          AppRoutes.tripPlanner,
          AppRoutes.messages,
          AppRoutes.translate,
          AppRoutes.aiSearch,
          AppRoutes.feedback,
          AppRoutes.popularApps,
        ],
      );
    });

- [x] Step 2: Run the focused test and verify it fails for the current order

Run:

    cd frontend && flutter test test/features/home/data/home_feature_data_test.dart --plain-name "home quick actions use the requested row-major order"

Expected: the test fails because the current list begins with Trip Planner, Forum, Translate, and Send Report.

- [x] Step 3: Reorder only the existing homeFeatures entries

Rewrite the list in frontend/lib/features/home/data/home_feature_data.dart to this order while keeping each entry's current icon and route:

    const List<FeatureItem> homeFeatures = <FeatureItem>[
      FeatureItem(
        title: 'Recommend',
        icon: Icons.recommend_outlined,
        route: AppRoutes.recommendWhereSearch,
      ),
      FeatureItem(
        title: 'Explore',
        icon: Icons.explore_outlined,
        route: AppRoutes.explore,
      ),
      FeatureItem(
        title: 'Trip Planner',
        icon: Icons.luggage_outlined,
        route: AppRoutes.tripPlanner,
      ),
      FeatureItem(
        title: 'Forum',
        icon: Icons.forum_outlined,
        route: AppRoutes.messages,
      ),
      FeatureItem(
        title: 'Translate',
        icon: Icons.translate_outlined,
        route: AppRoutes.translate,
      ),
      FeatureItem(
        title: 'AI Search',
        icon: Icons.auto_awesome_outlined,
        route: AppRoutes.aiSearch,
      ),
      FeatureItem(
        title: 'Send\nReport',
        icon: Icons.report_problem_outlined,
        route: AppRoutes.feedback,
      ),
      FeatureItem(
        title: 'Popular\nApps',
        icon: Icons.apps_outlined,
        route: AppRoutes.popularApps,
      ),
    ];

- [x] Step 4: Run the focused Home data tests

Run:

    cd frontend && flutter test test/features/home/data/home_feature_data_test.dart

Expected: all tests pass, including the existing Forum route and Recommend localization assertions.

- [x] Step 5: Commit the Home ordering change

    git add frontend/lib/features/home/data/home_feature_data.dart frontend/test/features/home/data/home_feature_data_test.dart
    git commit -m "feat: reorder home quick actions"

### Task 2: Add Controlled-Year Support to the Shared Calendar

**Files:**
- Modify: frontend/lib/core/widgets/date_range_calendar.dart:4-326,431-517
- Modify: frontend/test/core/widgets/date_range_calendar_test.dart:8-249

**Interfaces:**
- Consumes: existing DateRangeCalendar selection callbacks and optional firstDate, initialRange, and allowOneDayMode values.
- Produces: DateRangeYearNavigation, DateRangeCalendar.visibleYear, and DateRangeCalendar.showYearNavigation for TripDurationPage; default construction remains behavior-compatible for all existing callers.

- [x] Step 1: Write failing controlled-year widget tests

Add tests to frontend/test/core/widgets/date_range_calendar_test.dart. They use stable month keys that the implementation will add around each month card:

    testWidgets('can render a controlled year without an internal year row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController.instance,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 700,
                child: DateRangeCalendar(
                  firstDate: DateTime(2027, 1, 1),
                  visibleYear: 2027,
                  showYearNavigation: false,
                  onRangeChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DateRangeYearNavigation), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('calendar-month-2027-2')),
        findsOneWidget,
      );
    });

    testWidgets('controlled year changes preserve the selected range', (
      WidgetTester tester,
    ) async {
      final GlobalKey calendarKey = GlobalKey();

      Future<void> pumpCalendar(int year) {
        return tester.pumpWidget(
          AppLanguageScope(
            controller: AppLanguageController.instance,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 700,
                  child: DateRangeCalendar(
                    key: calendarKey,
                    firstDate: DateTime(2026, 1, 1),
                    visibleYear: year,
                    showYearNavigation: false,
                    initialRange: const DateTimeRange(
                      start: DateTime(2026, 1, 20),
                      end: DateTime(2026, 1, 22),
                    ),
                    onRangeChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await pumpCalendar(2026);
      await tester.pumpAndSettle();
      expect(find.text('Jan 20  →  Jan 22'), findsOneWidget);

      await pumpCalendar(2027);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('calendar-month-2027-1')),
        findsOneWidget,
      );
      expect(find.text('Jan 20  →  Jan 22'), findsOneWidget);
    });

- [x] Step 2: Run the new tests and verify the API is missing

Run:

    cd frontend && flutter test test/core/widgets/date_range_calendar_test.dart --plain-name "can render a controlled year without an internal year row"
    cd frontend && flutter test test/core/widgets/date_range_calendar_test.dart --plain-name "controlled year changes preserve the selected range"

Expected: compilation/test failure because DateRangeCalendar does not yet accept visibleYear/showYearNavigation, DateRangeYearNavigation does not yet exist, and stable month keys are not yet present.

- [x] Step 3: Add the public year-navigation interface

In frontend/lib/core/widgets/date_range_calendar.dart, add these fields to DateRangeCalendar:

    this.visibleYear,
    this.showYearNavigation = true,

and these fields to the widget class:

    final int? visibleYear;
    final bool showYearNavigation;

Add a public widget before the private sub-widget section:

    class DateRangeYearNavigation extends StatelessWidget {
      const DateRangeYearNavigation({
        super.key,
        required this.year,
        required this.onPreviousYear,
        required this.onNextYear,
      });

      final int year;
      final VoidCallback onPreviousYear;
      final VoidCallback onNextYear;

      @override
      Widget build(BuildContext context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _NavCircleButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPreviousYear,
              ),
              const SizedBox(width: 14),
              Container(
                key: const Key('date-range-visible-year'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surface.withValues(
                          alpha: 0.94,
                        )
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$year',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _NavCircleButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextYear,
              ),
            ],
          ),
        );
      }
    }

This moves the current year-row visual unchanged into a reusable public widget. The private _NavCircleButton remains shared by the new widget.

- [x] Step 4: Make the calendar year optionally controlled

Update _DateRangeCalendarState.initState so _year uses the external value when provided:

    _year = widget.visibleYear ?? _initialVisibleDate.year;

Add didUpdateWidget so a parent year change updates the rendered months without resetting _start, _end, or _isOneDayMode:

    @override
    void didUpdateWidget(covariant DateRangeCalendar oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (widget.visibleYear != null && widget.visibleYear != _year) {
        _year = widget.visibleYear!;
      }
    }

Replace the inline year-row Padding in build with this conditional:

    if (widget.showYearNavigation)
      DateRangeYearNavigation(
        year: _year,
        onPreviousYear: () => setState(() => _year--),
        onNextYear: () => setState(() => _year++),
      ),

Keep the summary, one-day toggle, and month list in their existing order. Add a stable key to the summary card:

    _RangeSummaryCard(
      key: const Key('calendar-range-summary'),
      summary: context.l10n.ui(_summaryText),
      duration: context.l10n.ui(_durationText),
      isComplete: _hasRange,
    ),

Give every month wrapper a stable year/month key while retaining _initialMonthKey for the existing initial reveal:

    child: KeyedSubtree(
      key: ValueKey<String>('calendar-month-$_year-$month'),
      child: _MonthCard(
        key: _year == _initialVisibleDate.year &&
                month == _initialVisibleDate.month
            ? _initialMonthKey
            : null,
        year: _year,
        month: month,
        monthName: context.l10n.ui(_monthNames[index]),
        weekdayLabels: _weekdayLabels
            .map(context.l10n.ui)
            .toList(growable: false),
        hasCompletedRange: _hasRange,
        firstDate: widget.firstDate,
        onDayTap: _onDayTap,
        isStart: _isStart,
        isEnd: _isEnd,
        isInRange: _isInRange,
      ),
    ),

Allow _RangeSummaryCard to accept super.key in its constructor. Do not alter any date-selection methods or the bounded/unbounded list physics.

- [x] Step 5: Run the calendar test suite

Run:

    cd frontend && dart format lib/core/widgets/date_range_calendar.dart test/core/widgets/date_range_calendar_test.dart
    cd frontend && flutter test test/core/widgets/date_range_calendar_test.dart

Expected: the new controlled-year tests and all existing localization, sliver, minimum-date, range, one-day, and mode-switch tests pass.

- [x] Step 6: Commit the shared-calendar API change

    git add frontend/lib/core/widgets/date_range_calendar.dart frontend/test/core/widgets/date_range_calendar_test.dart
    git commit -m "feat: support externally controlled calendar year"

### Task 3: Pin the Year Navigation in Trip Planner

**Files:**
- Modify: frontend/lib/features/planner/presentation/trip_duration_page.dart:8-49
- Modify: frontend/lib/features/planner/presentation/widgets/planner_step_scaffold.dart:268-290
- Create: frontend/test/features/planner/presentation/trip_duration_page_test.dart

**Interfaces:**
- Consumes: DateRangeYearNavigation, DateRangeCalendar.visibleYear, DateRangeCalendar.showYearNavigation, and PlannerStepScaffold.stickyBodyHeader.
- Produces: one pinned DateRangeYearNavigation plus one scrolling DateRangeCalendar for both Leisure and Business TripWizardData values.

- [x] Step 1: Write failing Trip Planner integration tests

Create frontend/test/features/planner/presentation/trip_duration_page_test.dart with this local-language setup pattern:

    import 'package:flutter/material.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:hellovietnam/core/language/app_language.dart';
    import 'package:hellovietnam/core/storage/local_storage.dart';
    import 'package:hellovietnam/core/widgets/date_range_calendar.dart';
    import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
    import 'package:hellovietnam/features/planner/presentation/trip_duration_page.dart';
    import 'package:shared_preferences/shared_preferences.dart';

    void main() {
      setUp(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await LocalStorage.instance.initialize();
        await AppLanguageController.instance.setLanguage(AppLanguage.english);
      });

      Future<void> pumpDurationPage(
        WidgetTester tester,
        TripWizardData wizard,
      ) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        await tester.pumpWidget(
          AppLanguageScope(
            controller: AppLanguageController.instance,
            child: MaterialApp(home: TripDurationPage(wizard: wizard)),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('pins the year row while the calendar content scrolls', (
        WidgetTester tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpDurationPage(
          tester,
          const TripWizardData(tripType: 'leisure'),
        );

        final Finder scrollFinder = find.byType(CustomScrollView);
        final Rect viewport = tester.getRect(scrollFinder);
        final Finder yearFinder = find.byKey(
          const Key('trip-duration-year-navigation'),
        );
        final double initialYearTop = tester.getTopLeft(yearFinder).dy;

        await tester.drag(scrollFinder, const Offset(0, -700));
        await tester.pumpAndSettle();

        final double pinnedYearTop = tester.getTopLeft(yearFinder).dy;
        final double summaryTop = tester
            .getTopLeft(find.byKey(const Key('calendar-range-summary')))
            .dy;

        expect(find.byType(DateRangeYearNavigation), findsOneWidget);
        expect(pinnedYearTop, lessThan(initialYearTop));
        expect(pinnedYearTop, closeTo(viewport.top, 1.0));
        expect(summaryTop, lessThan(viewport.top));
      });

      testWidgets('uses the same pinned year structure for business trips', (
        WidgetTester tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpDurationPage(
          tester,
          const TripWizardData(
            tripType: 'business',
            businessAddress: 'District 1, Ho Chi Minh City',
            targetLat: 10.7756,
            targetLng: 106.7019,
          ),
        );

        expect(find.byType(DateRangeCalendar), findsOneWidget);
        expect(find.byType(DateRangeYearNavigation), findsOneWidget);
        expect(
          find.byKey(const Key('trip-duration-year-navigation')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('calendar-range-summary')), findsOneWidget);
        expect(find.byKey(const Key('one-day-trip-toggle')), findsOneWidget);
      });

      testWidgets('year controls update the displayed year and month body', (
        WidgetTester tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpDurationPage(
          tester,
          const TripWizardData(tripType: 'leisure'),
        );

        final int currentYear = DateTime.now().year;
        final Finder yearHeader = find.byKey(
          const Key('trip-duration-year-navigation'),
        );
        final Finder nextYearButton = find.descendant(
          of: yearHeader,
          matching: find.byIcon(Icons.chevron_right_rounded),
        );

        await tester.tap(nextYearButton);
        await tester.pumpAndSettle();

        expect(find.text((currentYear + 1).toString()), findsOneWidget);
        expect(
          find.byKey(
            ValueKey<String>(
              'calendar-month-' + (currentYear + 1).toString() + '-1',
            ),
          ),
          findsOneWidget,
        );
      });
    }

- [x] Step 2: Run the new integration tests and verify they fail

Run:

    cd frontend && flutter test test/features/planner/presentation/trip_duration_page_test.dart

Expected: compilation failure because TripDurationPage does not yet render the keyed external year header or configure the calendar to hide its internal row; after the API task, the pinning assertions still fail until this integration is added.

- [x] Step 3: Add visible-year state and compose the sticky header

In _TripDurationPageState, initialize and mutate the displayed year:

    int _visibleYear = DateTime.now().year;

    void _showPreviousYear() {
      setState(() => _visibleYear--);
    }

    void _showNextYear() {
      setState(() => _visibleYear++);
    }

Update PlannerStepScaffold construction in build:

    return PlannerStepScaffold(
      currentStep: 3,
      badgeIcon: Icons.calendar_today_outlined,
      title: "When's your trip?",
      subtitle: 'Choose your travel dates',
      onBack: () => context.pop(),
      nextEnabled: _selectedRange != null,
      onNext: _onNext,
      stickyBodyHeader: DateRangeYearNavigation(
        key: const Key('trip-duration-year-navigation'),
        year: _visibleYear,
        onPreviousYear: _showPreviousYear,
        onNextYear: _showNextYear,
      ),
      stickyBodyHeaderExtent: 76,
      body: DateRangeCalendar(
        firstDate: DateTime.now(),
        visibleYear: _visibleYear,
        showYearNavigation: false,
        allowOneDayMode: true,
        onRangeChanged: (DateTimeRange? range) =>
            setState(() => _selectedRange = range),
      ),
    );

The sticky header is inserted by the existing scaffold before the body sliver, so only the year row pins. The calendar remains a single unbounded SliverToBoxAdapter body; its summary and month list continue to scroll in their current order.

The scaffold delegate wraps its gradient and padding in a tight SizedBox using the declared extent. This keeps the sliver's layoutExtent and paintExtent equal when the sticky child has a smaller intrinsic height.

- [x] Step 4: Run the focused Trip Planner tests

Run:

    cd frontend && dart format lib/features/planner/presentation/trip_duration_page.dart lib/features/planner/presentation/widgets/planner_step_scaffold.dart test/features/planner/presentation/trip_duration_page_test.dart
    cd frontend && flutter test test/features/planner/presentation/trip_duration_page_test.dart test/features/planner/presentation/business_location_page_test.dart

Expected: the Leisure pinning test and Business shared-layout test pass without layout exceptions. Existing Business location tests remain green.

- [ ] Step 5: Commit the Trip Planner integration

    git add frontend/lib/features/planner/presentation/trip_duration_page.dart frontend/lib/features/planner/presentation/widgets/planner_step_scaffold.dart frontend/test/features/planner/presentation/trip_duration_page_test.dart frontend/test/features/planner/presentation/business_location_page_test.dart
    git commit -m "feat: pin trip planner year navigation"

### Task 4: Run Formatting, Analysis, and Regression Verification

**Files:**
- Verify only; no additional source files.

**Interfaces:**
- Consumes: the three committed changes above.
- Produces: fresh evidence that Home ordering, shared calendar behavior, and both Trip Planner modes work together.

- [ ] Step 1: Format all changed Dart files

Run:

    cd frontend && dart format lib/features/home/data/home_feature_data.dart test/features/home/data/home_feature_data_test.dart lib/core/widgets/date_range_calendar.dart test/core/widgets/date_range_calendar_test.dart lib/features/planner/presentation/trip_duration_page.dart lib/features/planner/presentation/widgets/planner_step_scaffold.dart test/features/planner/presentation/trip_duration_page_test.dart test/features/planner/presentation/business_location_page_test.dart

Expected: formatter exits successfully and reports no remaining formatting changes on a second run.

- [ ] Step 2: Run focused regression tests

Run:

    cd frontend && flutter test test/features/home/data/home_feature_data_test.dart test/core/widgets/date_range_calendar_test.dart test/features/planner/presentation/trip_duration_page_test.dart test/features/planner/presentation/business_location_page_test.dart

Expected: all tests pass with zero layout exceptions.

- [ ] Step 3: Run the related Home, calendar, and Planner test directories

Run:

    cd frontend && flutter test test/features/home test/features/planner/presentation test/core/widgets/date_range_calendar_test.dart

Expected: all related tests pass; no test may be skipped to hide a failure.

- [ ] Step 4: Analyze the changed production files

Run:

    cd frontend && flutter analyze lib/features/home/data/home_feature_data.dart lib/core/widgets/date_range_calendar.dart lib/features/planner/presentation/trip_duration_page.dart lib/features/planner/presentation/widgets/planner_step_scaffold.dart

Expected: No issues found!.

- [ ] Step 5: Inspect the final diff and worktree

Run:

    git diff --check HEAD~3 HEAD
    git status --short --branch
    git log --oneline --decorate -5

Expected: no whitespace errors, no untracked or unstaged files from this task, and the three feature commits are present. Do not push or merge unless separately requested.
