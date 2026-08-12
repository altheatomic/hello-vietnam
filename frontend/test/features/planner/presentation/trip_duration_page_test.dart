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
    await pumpDurationPage(tester, const TripWizardData(tripType: 'leisure'));

    final Finder scrollFinder = find.byType(CustomScrollView);
    final Rect viewport = tester.getRect(scrollFinder);
    final Finder yearFinder = find.byKey(
      const Key('trip-duration-year-navigation'),
    );
    final double initialYearTop = tester.getTopLeft(yearFinder).dy;
    final double initialSummaryTop = tester
        .getTopLeft(find.byKey(const Key('calendar-range-summary')))
        .dy;

    await tester.drag(scrollFinder, const Offset(0, -700));
    await tester.pumpAndSettle();

    final double pinnedYearTop = tester.getTopLeft(yearFinder).dy;
    final double summaryTop = tester
        .getTopLeft(find.byKey(const Key('calendar-range-summary')))
        .dy;

    expect(find.byType(DateRangeYearNavigation), findsOneWidget);
    expect(pinnedYearTop, closeTo(initialYearTop, 1.0));
    expect(summaryTop, lessThan(initialSummaryTop));
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
    await pumpDurationPage(tester, const TripWizardData(tripType: 'leisure'));

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
