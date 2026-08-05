import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/presentation/trip_day_detail_page.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

TripPlannerActivityData place(
  String title, {
  required String start,
  String? end,
  String tag = 'culture',
  double lat = 16.07,
  double lng = 108.22,
  String? address,
}) {
  return TripPlannerActivityData(
    title: title,
    time: start,
    endTime: end,
    slot: 'Morning',
    tag: tag,
    description: '',
    distanceLabel: '',
    tips: const <String>[],
    nearbyPlaces: const <TripPlannerNearbyPlace>[],
    lat: lat,
    lng: lng,
    address: address,
  );
}

TripPlannerDayData dayWith(List<TripPlannerActivityData> activities) {
  return TripPlannerDayData(
    dayLabel: 'Day 1',
    date: '2026-08-05',
    activityCountLabel: '${activities.length} activities',
    moreActivitiesLabel: '',
    activities: activities,
    gradientColors: const <Color>[Colors.white, Colors.white],
  );
}

Future<bool> pumpDay(
  WidgetTester tester,
  TripPlannerDayData day, {
  NearbyRestaurantsLauncher launcher = _successfulLauncher,
}) async {
  await tester.pumpWidget(
    AppLanguageScope(
      controller: AppLanguageController.instance,
      child: MaterialApp(
        home: TripDayDetailPage(
          dayIndex: 0,
          dayData: day,
          nearbyRestaurantsLauncher: launcher,
        ),
      ),
    ),
  );
  await tester.pump();
  return true;
}

Future<bool> _successfulLauncher({
  required double lat,
  required double lng,
  String? placeName,
  String? address,
}) async => true;

void main() {
  testWidgets('renders one card after the selected lunch anchor', (
    WidgetTester tester,
  ) async {
    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place('Lunch Anchor', start: '11:20', end: '13:00'),
        place('Afternoon Place', start: '14:00', end: '15:00'),
      ]),
    );

    expect(find.byKey(const Key('lunch-discovery-card')), findsOneWidget);
    final cardTop = tester
        .getTopLeft(find.byKey(const Key('lunch-discovery-card')))
        .dy;
    final anchorBottom = tester.getBottomLeft(find.text('Lunch Anchor')).dy;
    final nextTop = tester.getTopLeft(find.text('Afternoon Place')).dy;
    expect(cardTop, greaterThan(anchorBottom));
    expect(cardTop, lessThan(nextTop));
  });

  testWidgets('forwards anchor coordinates when the action is tapped', (
    WidgetTester tester,
  ) async {
    final launches = <({
      double lat,
      double lng,
      String? placeName,
      String? address,
    })>[];
    Future<bool> launcher({
      required double lat,
      required double lng,
      String? placeName,
      String? address,
    }) async {
      launches.add(
        (lat: lat, lng: lng, placeName: placeName, address: address),
      );
      return true;
    }

    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place(
          'Lunch Anchor',
          start: '11:20',
          end: '13:00',
          address: '1A Tràng Tiền, Hoàn Kiếm, Hà Nội',
        ),
      ]),
      launcher: launcher,
    );

    final action = find.text('View restaurants on Google Maps');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();

    expect(
      launches,
      <({
        double lat,
        double lng,
        String? placeName,
        String? address,
      })>[
        (
          lat: 16.07,
          lng: 108.22,
          placeName: 'Lunch Anchor',
          address: '1A Tràng Tiền, Hoàn Kiếm, Hà Nội',
        ),
      ],
    );
  });

  testWidgets('multiple synthetic lunch breaks still render one card', (
    WidgetTester tester,
  ) async {
    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place('Lunch Anchor', start: '11:20', end: '13:00'),
        place('Synthetic Lunch 1', start: '12:00', tag: 'lunch_break'),
        place('Synthetic Lunch 2', start: '12:30', tag: 'lunch_break'),
      ]),
    );

    expect(find.byKey(const Key('lunch-discovery-card')), findsOneWidget);
    expect(find.text('Synthetic Lunch 1'), findsNothing);
    expect(find.text('Synthetic Lunch 2'), findsNothing);
  });

  testWidgets('all-afternoon day inserts after the first real place', (
    WidgetTester tester,
  ) async {
    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place('First Place', start: '13:00', end: '14:00'),
        place('Second Place', start: '15:00', end: '16:00'),
      ]),
    );

    final cardTop = tester
        .getTopLeft(find.byKey(const Key('lunch-discovery-card')))
        .dy;
    expect(cardTop, greaterThan(tester.getBottomLeft(find.text('First Place')).dy));
    expect(cardTop, lessThan(tester.getTopLeft(find.text('Second Place')).dy));
  });

  testWidgets('empty real-place day has no discovery card', (
    WidgetTester tester,
  ) async {
    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place('Lunch Break', start: '12:00', tag: 'lunch_break'),
      ]),
    );

    expect(find.byKey(const Key('lunch-discovery-card')), findsNothing);
  });

  testWidgets('false launcher result shows localized failure snackbar', (
    WidgetTester tester,
  ) async {
    Future<bool> launcher({
      required double lat,
      required double lng,
      String? placeName,
      String? address,
    }) async => false;

    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place('Lunch Anchor', start: '11:20', end: '13:00'),
      ]),
      launcher: launcher,
    );

    final action = find.text('View restaurants on Google Maps');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();

    expect(
      find.text('Could not open Google Maps. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid coordinates disable action and explain why', (
    WidgetTester tester,
  ) async {
    await pumpDay(
      tester,
      dayWith(<TripPlannerActivityData>[
        place('Unknown Place', start: '11:20', end: '13:00', lat: 0, lng: 0),
      ]),
    );

    expect(
      find.text('Restaurant search is unavailable for this location.'),
      findsOneWidget,
    );
    final InkWell action = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('View restaurants on Google Maps'),
        matching: find.byType(InkWell),
      ),
    );
    expect(action.onTap, isNull);
  });
}
