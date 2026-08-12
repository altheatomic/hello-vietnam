import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
  });

  testWidgets('localizes calendar labels when app language is Vietnamese', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 620,
              child: DateRangeCalendar(onRangeChanged: (_) {}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Chọn ngày đi'), findsOneWidget);
    expect(find.text('Chọn ngày'), findsOneWidget);
    expect(find.text('Tháng 1'), findsOneWidget);
    expect(find.text('CN'), findsWidgets);
  });

  testWidgets('renders inside a sliver with unbounded height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: DateRangeCalendar(onRangeChanged: (_) {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Chọn ngày đi'), findsOneWidget);
    expect(find.text('Tháng 1'), findsOneWidget);
  });

  testWidgets('reveals the first selectable month when opened in a sliver', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: DateRangeCalendar(
                    firstDate: DateTime(2026, 7, 20),
                    onRangeChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ScrollableState outerScroll = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final Rect viewport = tester.getRect(find.byType(CustomScrollView));
    final Rect currentMonth = tester.getRect(find.text('Tháng 7'));
    expect(outerScroll.position.pixels, greaterThan(0));
    expect(viewport.overlaps(currentMonth), isTrue);
  });

  testWidgets('does not select dates before the first selectable date', (
    WidgetTester tester,
  ) async {
    int callbackCount = 0;
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: DateRangeCalendar(
                firstDate: DateTime(2026, 1, 20),
                onRangeChanged: (_) => callbackCount++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('19').first);
    expect(callbackCount, 0);

    await tester.tap(find.text('20').first);
    expect(callbackCount, 1);
  });

  testWidgets('keeps the default range selection behavior', (
    WidgetTester tester,
  ) async {
    final List<DateTimeRange?> changes = <DateTimeRange?>[];
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: DateRangeCalendar(
                firstDate: DateTime(2026),
                onRangeChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('one-day-trip-toggle')), findsNothing);

    await tester.tap(find.text('20').first);
    expect(changes, <DateTimeRange?>[null]);

    await tester.tap(find.text('22').first);
    expect(
      changes.last,
      DateTimeRange(start: DateTime(2026, 1, 20), end: DateTime(2026, 1, 22)),
    );

    await tester.tap(find.text('22').first);
    expect(changes.last, isNull);
  });

  testWidgets('one-day mode selects, replaces, and deselects one date', (
    WidgetTester tester,
  ) async {
    final List<DateTimeRange?> changes = <DateTimeRange?>[];
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: DateRangeCalendar(
                firstDate: DateTime(2026),
                allowOneDayMode: true,
                onRangeChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('one-day-trip-toggle')));
    expect(changes, <DateTimeRange?>[null]);

    await tester.tap(find.text('20').first);
    expect(
      changes.last,
      DateTimeRange(start: DateTime(2026, 1, 20), end: DateTime(2026, 1, 20)),
    );

    await tester.tap(find.text('22').first);
    expect(
      changes.last,
      DateTimeRange(start: DateTime(2026, 1, 22), end: DateTime(2026, 1, 22)),
    );

    await tester.tap(find.text('22').first);
    expect(changes.last, isNull);
  });

  testWidgets('switching modes resets or preserves the start as specified', (
    WidgetTester tester,
  ) async {
    final List<DateTimeRange?> changes = <DateTimeRange?>[];
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: DateRangeCalendar(
                firstDate: DateTime(2026),
                allowOneDayMode: true,
                onRangeChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('20').first);
    await tester.tap(find.text('22').first);
    expect(changes.last, isNotNull);

    await tester.tap(find.byKey(const Key('one-day-trip-toggle')));
    expect(changes.last, isNull);

    await tester.tap(find.text('23').first);
    expect(
      changes.last,
      DateTimeRange(start: DateTime(2026, 1, 23), end: DateTime(2026, 1, 23)),
    );

    await tester.tap(find.byKey(const Key('one-day-trip-toggle')));
    expect(changes.last, isNull);

    await tester.tap(find.text('25').first);
    expect(
      changes.last,
      DateTimeRange(start: DateTime(2026, 1, 23), end: DateTime(2026, 1, 25)),
    );
  });

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
                  initialRange: DateTimeRange(
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
}
