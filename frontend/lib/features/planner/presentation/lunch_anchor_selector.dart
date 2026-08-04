import 'trip_planner_mock_data.dart';

const int _lunchStartMinutes = 11 * 60 + 30;
const int _lunchEndMinutes = 13 * 60;

int? _parseClockMinutes(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

TripPlannerActivityData? selectLunchAnchor(
  List<TripPlannerActivityData> activities,
) {
  TripPlannerActivityData? firstReal;
  TripPlannerActivityData? latestInWindow;
  var latestInWindowMinutes = -1;
  TripPlannerActivityData? latestBeforeLunch;
  var latestBeforeLunchMinutes = -1;
  TripPlannerActivityData? latestStart;
  var latestStartMinutes = -1;

  for (final activity in activities) {
    if (activity.tag == 'lunch_break') continue;
    firstReal ??= activity;

    final endMinutes = _parseClockMinutes(activity.endTime);
    if (endMinutes != null) {
      if (endMinutes >= _lunchStartMinutes &&
          endMinutes <= _lunchEndMinutes &&
          endMinutes >= latestInWindowMinutes) {
        latestInWindow = activity;
        latestInWindowMinutes = endMinutes;
      } else if (endMinutes < _lunchStartMinutes &&
          endMinutes >= latestBeforeLunchMinutes) {
        latestBeforeLunch = activity;
        latestBeforeLunchMinutes = endMinutes;
      }
    }

    final startMinutes = _parseClockMinutes(activity.time);
    if (startMinutes != null &&
        startMinutes < _lunchEndMinutes &&
        startMinutes >= latestStartMinutes) {
      latestStart = activity;
      latestStartMinutes = startMinutes;
    }
  }

  return latestInWindow ?? latestBeforeLunch ?? latestStart ?? firstReal;
}
