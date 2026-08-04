import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

void main() {
  test('preserves nullable endTime through JSON', () {
    const activity = TripPlannerActivityData(
      title: 'Museum',
      time: '10:30',
      endTime: '11:45',
      slot: 'Morning',
      tag: 'culture',
      description: '',
      distanceLabel: '',
      tips: <String>[],
      nearbyPlaces: <TripPlannerNearbyPlace>[],
      lat: 16.07,
      lng: 108.22,
    );

    final restored = TripPlannerActivityData.fromJson(activity.toJson());

    expect(activity.toJson()['endTime'], '11:45');
    expect(restored.endTime, '11:45');
  });

  test('deserializes activity JSON created before endTime existed', () {
    final restored = TripPlannerActivityData.fromJson(<String, dynamic>{
      'title': 'Museum',
      'time': '10:30',
      'slot': 'Morning',
      'tag': 'culture',
      'description': '',
      'distanceLabel': '',
      'tips': <String>[],
      'nearbyPlaces': <Map<String, dynamic>>[],
      'lat': 16.07,
      'lng': 108.22,
      'imageUrl': null,
    });

    expect(restored.endTime, isNull);
  });
}
