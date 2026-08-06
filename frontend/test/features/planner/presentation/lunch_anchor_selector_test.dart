import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/presentation/lunch_anchor_selector.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

TripPlannerActivityData _place(String title, String time, {String tag = 'culture'}) {
  return TripPlannerActivityData(
    title: title,
    time: time,
    slot: 'Morning',
    tag: tag,
    description: '',
    distanceLabel: '',
    tips: const <String>[],
    nearbyPlaces: const <TripPlannerNearbyPlace>[],
    lat: 21.0,
    lng: 105.0,
  );
}

void main() {
  test('selects the last real place before noon', () {
    final selected = selectLunchAnchor(<TripPlannerActivityData>[
      _place('Morning One', '08:00'),
      _place('Morning Two', '10:30'),
      _place('Afternoon', '13:30'),
    ]);

    expect(selected?.title, 'Morning Two');
  });

  test('falls back to the first real place on an afternoon-only day', () {
    final selected = selectLunchAnchor(<TripPlannerActivityData>[
      _place('Afternoon One', '13:30'),
      _place('Afternoon Two', '15:00'),
    ]);

    expect(selected?.title, 'Afternoon One');
  });

  test('ignores synthetic lunch-break entries', () {
    final selected = selectLunchAnchor(<TripPlannerActivityData>[
      _place('Morning Place', '10:30'),
      _place('Lunch Break', '12:00', tag: 'lunch_break'),
    ]);

    expect(selected?.title, 'Morning Place');
  });

  test('returns null when there are no real places', () {
    expect(
      selectLunchAnchor(<TripPlannerActivityData>[
        _place('Lunch Break', '12:00', tag: 'lunch_break'),
      ]),
      isNull,
    );
  });
}
