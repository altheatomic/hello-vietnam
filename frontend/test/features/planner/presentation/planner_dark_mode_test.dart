import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/home/presentation/widgets/active_trip_card.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_page.dart';
import 'package:hellovietnam/features/planner/presentation/trip_location_page.dart';
import 'package:hellovietnam/features/planner/presentation/trip_result_page.dart';
import 'package:hellovietnam/features/planner/presentation/saved_trips_page.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

void main() {
  testWidgets('planner landing screen uses a dark background and chrome', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const TripPlannerPage()),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final Container background = scaffold.body! as Container;
    final BoxDecoration decoration = background.decoration! as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;
    final Text subtitle = tester.widget<Text>(
      find.text("Let's create your perfect trip"),
    );
    final Icon backIcon = tester.widget<Icon>(
      find.byIcon(Icons.arrow_back_rounded),
    );

    expect(gradient.colors.first.computeLuminance(), lessThan(0.1));
    expect(subtitle.style?.color, darkTheme.colorScheme.onSurfaceVariant);
    expect(backIcon.color, darkTheme.colorScheme.onSurface);
  });

  testWidgets('planner step scaffold uses dark surfaces and readable text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: PlannerStepScaffold(
          currentStep: 1,
          badgeIcon: Icons.place_outlined,
          title: 'Where do you want to go?',
          subtitle: 'Choose a destination',
          onBack: () {},
          body: const SizedBox.shrink(),
        ),
      ),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final Container background = scaffold.body! as Container;
    final BoxDecoration decoration = background.decoration! as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;
    final Text title = tester.widget<Text>(find.text('Personalized Itinerary'));

    expect(gradient.colors.first.computeLuminance(), lessThan(0.1));
    expect(title.style?.color, buildDarkTheme().colorScheme.onSurface);
  });

  testWidgets('destination search uses a subtle dark outline', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const TripLocationPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final Finder searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    final DecoratedBox searchShell = tester.widget<DecoratedBox>(
      find.ancestor(of: searchField, matching: find.byType(DecoratedBox)).first,
    );
    final BoxDecoration decoration = searchShell.decoration as BoxDecoration;

    expect(
      (decoration.border! as Border).top.color,
      darkTheme.colorScheme.outline,
    );
  });

  testWidgets('active trip card uses a dark surface on the home page', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final ActiveTrip trip = ActiveTrip(
      title: 'Hanoi Adventure',
      days: <TripPlannerDayData>[TripPlannerMockData.tripDays.first],
      activatedAt: now,
      tripStartDate: DateTime(now.year, now.month, now.day + 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: Scaffold(
          body: ActiveTripCard(trip: trip, onViewOrRoute: () {}, onEnd: () {}),
        ),
      ),
    );

    final Iterable<Container> containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(ActiveTripCard),
        matching: find.byType(Container),
      ),
    );
    final Container card = containers.firstWhere((Container container) {
      final Decoration? decoration = container.decoration;
      return decoration is BoxDecoration && decoration.border != null;
    });
    final BoxDecoration decoration = card.decoration! as BoxDecoration;

    expect(decoration.color, buildDarkTheme().colorScheme.surface);
  });

  testWidgets('generated itinerary review uses dark page and day cards', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    const TripPlanResponse plan = TripPlanResponse(
      idPlan: 'plan-1',
      days: <TripPlanDay>[
        TripPlanDay(
          day: 1,
          date: '2026-07-21',
          places: <TripPlanPlace>[
            TripPlanPlace(
              order: 1,
              idPlace: 'place-1',
              name: 'Hoi An Ancient Town',
              slot: 'morning',
            ),
          ],
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: const TripResultPage(plan: plan),
      ),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final Container background = scaffold.body! as Container;
    final LinearGradient pageGradient =
        (background.decoration! as BoxDecoration).gradient! as LinearGradient;
    final Container dayCard = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((Container container) {
          final Decoration? decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.gradient is LinearGradient &&
              decoration.borderRadius == BorderRadius.circular(26);
        });
    final LinearGradient dayGradient =
        (dayCard.decoration! as BoxDecoration).gradient! as LinearGradient;

    expect(pageGradient.colors.first.computeLuminance(), lessThan(0.1));
    expect(dayGradient.colors.first.computeLuminance(), lessThan(0.1));
  });

  testWidgets('saved itinerary list uses a dark background', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const SavedTripsPage()),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final Container background = scaffold.body! as Container;
    final LinearGradient gradient =
        (background.decoration! as BoxDecoration).gradient! as LinearGradient;

    expect(gradient.colors.first.computeLuminance(), lessThan(0.1));
  });
}
