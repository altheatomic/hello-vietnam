import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/presentation/lunch_anchor_selector.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

void main() {
  test('selects the latest end inside the inclusive lunch window', () {
    final atStart = _activity(title: 'Early lunch', endTime: '11:30');
    final atEnd = _activity(title: 'Late lunch', endTime: '13:00');

    expect(selectLunchAnchor([atStart, atEnd]), same(atEnd));
  });

  test('selects the latest end before lunch when no in-window end exists', () {
    final earlier = _activity(title: 'Breakfast', endTime: '09:30');
    final later = _activity(title: 'Market', endTime: '11:29');

    expect(selectLunchAnchor([earlier, later]), same(later));
  });

  test('selects the latest start before lunch end when ends are invalid', () {
    final earlier = _activity(title: 'Gallery', time: '10:30', endTime: null);
    final later = _activity(title: 'Park', time: '12:45', endTime: 'not-a-time');

    expect(selectLunchAnchor([earlier, later]), same(later));
  });

  test('selects the first real activity when all starts are at or after lunch end', () {
    final first = _activity(title: 'Temple', time: '13:00', endTime: null);
    final second = _activity(title: 'Beach', time: '14:00', endTime: null);

    expect(selectLunchAnchor([first, second]), same(first));
  });

  test('ignores synthetic lunch breaks and returns null for only synthetic entries', () {
    final lunchBreak = _activity(title: 'Lunch break', tag: 'lunch_break');
    final restaurant = _activity(title: 'Restaurant', time: '12:00');

    expect(selectLunchAnchor([lunchBreak]), isNull);
    expect(selectLunchAnchor([lunchBreak, restaurant]), same(restaurant));
  });

  test('accepts seconds, rejects malformed clocks, and prefers later ties', () {
    final malformed = _activity(title: 'Malformed', endTime: '12:60');
    final firstTie = _activity(title: 'First tie', endTime: '12:30:45');
    final secondTie = _activity(title: 'Second tie', endTime: '12:30');

    expect(selectLunchAnchor([malformed, firstTie, secondTie]), same(secondTie));
  });
}

TripPlannerActivityData _activity({
  String title = 'Activity',
  String time = '10:00',
  String? endTime = '11:00',
  String tag = 'real',
}) {
  return TripPlannerActivityData(
    title: title,
    time: time,
    endTime: endTime,
    slot: 'Day',
    tag: tag,
    description: '',
    distanceLabel: '',
    tips: const <String>[],
    nearbyPlaces: const <TripPlannerNearbyPlace>[],
  );
}
