import 'trip_planner_mock_data.dart';

const int _noonMinutes = 12 * 60;

/// Returns the real itinerary place that anchors the lunch search card.
///
/// The last real place starting before noon is preferred. For an
/// afternoon-only itinerary, the first real place is used so every non-empty
/// day can still offer restaurant discovery.
TripPlannerActivityData? selectLunchAnchor(
  List<TripPlannerActivityData> activities,
) {
  final List<TripPlannerActivityData> realPlaces = activities
      .where((TripPlannerActivityData activity) => activity.tag != 'lunch_break')
      .toList(growable: false);
  if (realPlaces.isEmpty) return null;

  TripPlannerActivityData? lastBeforeNoon;
  for (final TripPlannerActivityData activity in realPlaces) {
    final int? startMinutes = _parseTime(activity.time);
    if (startMinutes != null && startMinutes < _noonMinutes) {
      lastBeforeNoon = activity;
    }
  }
  return lastBeforeNoon ?? realPlaces.first;
}

int? _parseTime(String value) {
  final Match? match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
  if (match == null) return null;

  final int? hour = int.tryParse(match.group(1)!);
  final int? minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}
