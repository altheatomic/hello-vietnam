import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/presentation/trip_day_detail_page.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

void main() {
  testWidgets('shows restaurant search after the last pre-noon place', (
    WidgetTester tester,
  ) async {
    double? selectedLat;
    double? selectedLng;
    final TripPlannerDayData day = _day(<TripPlannerActivityData>[
      _activity('08:00', 'First place', lat: 21.01, lng: 105.81),
      _activity('11:30', 'Lunch anchor', lat: 21.02, lng: 105.82),
      _activity('14:00', 'Afternoon place', lat: 21.03, lng: 105.83),
    ], provinceName: 'Hanoi');

    await tester.pumpWidget(
      MaterialApp(
        home: TripDayDetailPage(
          dayIndex: 0,
          dayData: day,
          nearbyRestaurantsLauncher: ({
            required lat,
            required lng,
            required placeName,
            required provinceName,
          }) async {
            selectedLat = lat;
            selectedLng = lng;
            expect(placeName, 'Lunch anchor');
            expect(provinceName, 'Hanoi');
            return true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('lunch-discovery-card')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('lunch-discovery-card'))).dy,
      greaterThan(tester.getTopLeft(find.text('Lunch anchor')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('lunch-discovery-card'))).dy,
      lessThan(tester.getTopLeft(find.text('Afternoon place')).dy),
    );

    await tester.ensureVisible(find.text('View restaurants on Google Maps'));
    await tester.tap(find.text('View restaurants on Google Maps'));
    expect(selectedLat, 21.02);
    expect(selectedLng, 105.82);
  });

  testWidgets('uses the first place for an afternoon-only day', (
    WidgetTester tester,
  ) async {
    final TripPlannerDayData day = _day(<TripPlannerActivityData>[
      _activity('13:00', 'Afternoon start', lat: 16.06, lng: 108.21),
      _activity('16:00', 'Later place', lat: 16.07, lng: 108.22),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: TripDayDetailPage(dayIndex: 0, dayData: day),
      ),
    );

    expect(find.byKey(const Key('lunch-discovery-card')), findsOneWidget);
    expect(find.text('Find restaurants near Afternoon start'), findsOneWidget);
  });

  testWidgets('disables restaurant search when anchor coordinates are invalid', (
    WidgetTester tester,
  ) async {
    final TripPlannerDayData day = _day(<TripPlannerActivityData>[
      _activity('09:00', 'Unknown place'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: TripDayDetailPage(dayIndex: 0, dayData: day),
      ),
    );

    expect(find.byKey(const Key('lunch-discovery-card')), findsOneWidget);
    expect(
      find.text('Restaurant search is unavailable for this location.'),
      findsOneWidget,
    );
    expect(find.text('View restaurants on Google Maps'), findsNothing);
  });
}

TripPlannerDayData _day(
  List<TripPlannerActivityData> activities, {
  String provinceName = '',
}) {
  return TripPlannerDayData(
    dayLabel: 'Day 1',
    date: '2026-08-06',
    activityCountLabel: '${activities.length} activities planned',
    moreActivitiesLabel: '',
    activities: activities,
    gradientColors: const <Color>[Colors.white, Colors.white],
    provinceName: provinceName,
  );
}

TripPlannerActivityData _activity(
  String time,
  String title, {
  double lat = 0,
  double lng = 0,
}) {
  return TripPlannerActivityData(
    title: title,
    time: time,
    slot: 'Morning',
    tag: 'culture',
    description: 'Description',
    distanceLabel: 'Nearby',
    tips: const <String>[],
    nearbyPlaces: const <TripPlannerNearbyPlace>[],
    lat: lat,
    lng: lng,
  );
}
