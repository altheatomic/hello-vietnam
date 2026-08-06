import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/presentation/trip_day_detail_page.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

/// Temporary verification test for the Goong travel-time row (_TravelTimeRow)
/// added between consecutive place cards in TripDayDetailPage. Covers the 3
/// scenarios called out in the implementation task: (a) both car+bike present,
/// (b) both null (hidden entirely), (c) only one of the two present.
void main() {
  TripPlannerActivityData activityAt({
    required String title,
    int? carSeconds,
    int? bikeSeconds,
    int? carMeters,
    int? bikeMeters,
  }) {
    return TripPlannerActivityData(
      title: title,
      time: '08:00',
      slot: 'Morning',
      tag: 'culture',
      description: '',
      distanceLabel: '',
      tips: const <String>[],
      nearbyPlaces: const <TripPlannerNearbyPlace>[],
      travelTimeCarSeconds: carSeconds,
      travelTimeBikeSeconds: bikeSeconds,
      travelDistanceCarMeters: carMeters,
      travelDistanceBikeMeters: bikeMeters,
    );
  }

  Future<void> pumpDay(
    WidgetTester tester,
    List<TripPlannerActivityData> activities,
  ) async {
    final TripPlannerDayData dayData = TripPlannerDayData(
      dayLabel: 'Day 1',
      date: 'Aug 6, 2026',
      activityCountLabel: '${activities.length} activities planned',
      moreActivitiesLabel: '',
      gradientColors: const <Color>[Color(0xFFE9F0FD), Color(0xFFE7FAFD)],
      activities: activities,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    await tester.pumpWidget(
      MaterialApp(home: TripDayDetailPage(dayIndex: 0, dayData: dayData)),
    );
  }

  testWidgets(
    '(a) car+bike both present: shows both icons, hides for first card',
    (WidgetTester tester) async {
      final activities = <TripPlannerActivityData>[
        activityAt(title: 'Place A'), // first of day: no travel data upstream
        activityAt(
          title: 'Place B',
          carSeconds: 360,
          bikeSeconds: 552,
          carMeters: 2800,
          bikeMeters: 2800,
        ),
      ];
      await pumpDay(tester, activities);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
      expect(find.textContaining('9 min'), findsOneWidget); // 552s -> 9 min
      expect(find.textContaining('6 min'), findsOneWidget); // 360s -> 6 min
      expect(find.textContaining('2.8km'), findsNWidgets(2));
    },
  );

  testWidgets('(b) both null: no travel-time row rendered at all', (
    WidgetTester tester,
  ) async {
    final activities = <TripPlannerActivityData>[
      activityAt(title: 'Place A'),
      activityAt(title: 'Place B'), // no travel data at all (skip-edge case)
    ];
    await pumpDay(tester, activities);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.two_wheeler), findsNothing);
    expect(find.byIcon(Icons.directions_car), findsNothing);
  });

  testWidgets('(c) only bike present: shows bike line only, hides car line', (
    WidgetTester tester,
  ) async {
    final activities = <TripPlannerActivityData>[
      activityAt(title: 'Place A'),
      activityAt(title: 'Place B', bikeSeconds: 300, bikeMeters: 900),
    ];
    await pumpDay(tester, activities);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsNothing);
    expect(find.textContaining('900m'), findsOneWidget);
  });
}
