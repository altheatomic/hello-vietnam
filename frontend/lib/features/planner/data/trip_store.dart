import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

// ── SharedPreferences keys (namespaced to avoid collisions) ──────────────────

const String _kTitle = 'trip_store.title';
const String _kActivatedAt = 'trip_store.activated_at';
const String _kTripStartDate = 'trip_store.trip_start_date';

// ── Public types ──────────────────────────────────────────────────────────────

enum TripStatus { upcoming, inProgress, completed }

/// A reference to a specific activity within the trip, including its day index.
class ActivityRef {
  const ActivityRef({required this.dayIndex, required this.activity});

  final int dayIndex;
  final TripPlannerActivityData activity;
}

// ── ActiveTrip ────────────────────────────────────────────────────────────────

/// Represents a trip that has been activated by the user.
///
/// Key design decisions:
/// - [activatedAt] records when the user tapped "Start Trip" — distinct from
///   when the itinerary actually begins.
/// - [tripStartDate] is midnight of the day that Day 1 maps to (today at
///   activation). This anchors the mock HH:mm schedule to real calendar dates
///   so status is always evaluated against current wall-clock time.
/// - [status], [relevantActivity], and [tripEndDate] are all computed from
///   real time — nothing is stored as a mutable index.
class ActiveTrip {
  ActiveTrip({
    required this.title,
    required this.days,
    required this.activatedAt,
    required this.tripStartDate,
  });

  final String title;
  final List<TripPlannerDayData> days;

  /// Exact timestamp when the user tapped "Start Trip".
  final DateTime activatedAt;

  /// Midnight of the calendar date that Day 1 of the itinerary maps to.
  /// Day N = tripStartDate + (N-1) days.
  final DateTime tripStartDate;

  /// How long after the last activity's scheduled start time the trip
  /// remains [TripStatus.inProgress] before flipping to [TripStatus.completed].
  ///
  /// Prevents an immediate flip to "completed" the moment the last activity
  /// begins — a traveller is realistically still doing it.
  static const Duration completionBuffer = Duration(hours: 2);

  // ── Calendar helpers ────────────────────────────────────────────────────────

  /// Returns the midnight DateTime for a given zero-based day index.
  DateTime dateForDay(int index) =>
      DateTime(tripStartDate.year, tripStartDate.month, tripStartDate.day)
          .add(Duration(days: index));

  /// Parses an "HH:mm" string into a full DateTime on the correct calendar day.
  DateTime activityDateTime(int dayIndex, String time) {
    final base = dateForDay(dayIndex);
    final parts = time.split(':');
    return DateTime(
      base.year,
      base.month,
      base.day,
      int.tryParse(parts[0]) ?? 0,
      parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  DateTime get _firstActivityAt =>
      activityDateTime(0, days.first.activities.first.time);

  DateTime get _lastActivityAt =>
      activityDateTime(days.length - 1, days.last.activities.last.time);

  /// When the trip is considered fully over: last activity start + buffer.
  DateTime get tripEndDate => _lastActivityAt.add(completionBuffer);

  // ── Status ──────────────────────────────────────────────────────────────────

  /// Derived purely from real wall-clock time vs. the itinerary schedule.
  /// Never stored — always recomputed so it stays accurate over time.
  TripStatus get status {
    final now = DateTime.now();
    if (now.isBefore(_firstActivityAt)) return TripStatus.upcoming;
    if (now.isAfter(tripEndDate)) return TripStatus.completed;
    return TripStatus.inProgress;
  }

  // ── Activity resolution ─────────────────────────────────────────────────────

  /// Returns the most actionable activity reference based on current time:
  ///
  /// - [TripStatus.upcoming]   → first activity of Day 1 (preview).
  /// - [TripStatus.inProgress] → first activity whose start time is still
  ///   in the future (next stop to navigate to).
  /// - [TripStatus.completed]  → last activity of the trip (reference).
  ActivityRef get relevantActivity {
    final now = DateTime.now();
    switch (status) {
      case TripStatus.upcoming:
        return ActivityRef(
          dayIndex: 0,
          activity: days.first.activities.first,
        );
      case TripStatus.inProgress:
        for (int d = 0; d < days.length; d++) {
          for (final act in days[d].activities) {
            if (now.isBefore(activityDateTime(d, act.time))) {
              return ActivityRef(dayIndex: d, activity: act);
            }
          }
        }
        // Edge case: all activities started but within completionBuffer.
        return ActivityRef(
          dayIndex: days.length - 1,
          activity: days.last.activities.last,
        );
      case TripStatus.completed:
        return ActivityRef(
          dayIndex: days.length - 1,
          activity: days.last.activities.last,
        );
    }
  }

  // ── Display helpers ─────────────────────────────────────────────────────────

  /// Human-readable summary of when the trip begins (used in upcoming state).
  String get startsSummary {
    final now = DateTime.now();
    final firstAt = _firstActivityAt;
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(firstAt.year, firstAt.month, firstAt.day);
    final diffDays = firstDay.difference(today).inDays;

    final timeStr = _fmtTime(firstAt);
    if (diffDays == 0) return 'Starts today at $timeStr';
    if (diffDays == 1) return 'Starts tomorrow at $timeStr';
    if (diffDays > 1) return 'Starts in $diffDays days at $timeStr';
    return 'Starts at $timeStr'; // fallback for diffDays < 0 (shouldn't reach upcoming)
  }

  /// Total activity count across all days.
  int get totalActivities =>
      days.fold(0, (sum, d) => sum + d.activities.length);

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── TripStore ─────────────────────────────────────────────────────────────────

/// Singleton store managing the user's active trip.
///
/// Responsibilities:
/// - Holds and exposes [activeTrip].
/// - Persists the active trip to [SharedPreferences] so it survives restarts.
/// - Runs a periodic timer that calls [notifyListeners] only when [TripStatus]
///   changes, keeping Home UI accurate without rebuild storms.
///
/// Follows the same ChangeNotifier singleton pattern as ForumStore.
class TripStore extends ChangeNotifier {
  TripStore._();

  static final TripStore instance = TripStore._();

  ActiveTrip? _activeTrip;
  TripStatus? _lastStatus;
  Timer? _refreshTimer;

  ActiveTrip? get activeTrip => _activeTrip;
  bool get hasActiveTrip => _activeTrip != null;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Must be called once in [main] before [runApp].
  ///
  /// Restores any persisted active trip from SharedPreferences so that the
  /// first build of HomePage already sees the correct state.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString(_kTitle);
      final activatedAtStr = prefs.getString(_kActivatedAt);
      final tripStartDateStr = prefs.getString(_kTripStartDate);

      if (title == null || activatedAtStr == null || tripStartDateStr == null) {
        return; // No persisted trip.
      }

      final activatedAt = DateTime.tryParse(activatedAtStr);
      final tripStartDate = DateTime.tryParse(tripStartDateStr);
      if (activatedAt == null || tripStartDate == null) return;

      _activeTrip = ActiveTrip(
        title: title,
        // Backend: replace with persisted real itinerary data when
        // trips are stored server-side. For now, mock data is always the
        // same so reconstructing from it is safe.
        days: TripPlannerMockData.tripDays,
        activatedAt: activatedAt,
        tripStartDate: tripStartDate,
      );
      _lastStatus = _activeTrip!.status;
      _startTimer();
      // No notifyListeners() — init() runs before runApp, listeners don't
      // exist yet. The first build reads _activeTrip directly.
    } catch (e) {
      // SharedPreferences failure is non-fatal: app continues without restore.
      debugPrint('TripStore.init: failed to restore persisted trip — $e');
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Activates a trip, anchoring Day 1 to today's calendar date.
  ///
  /// The itinerary HH:mm schedule is evaluated against real time starting
  /// today, so status and activity resolution are always meaningful.
  void startTrip({
    required String title,
    required List<TripPlannerDayData> days,
  }) {
    final now = DateTime.now();
    _activeTrip = ActiveTrip(
      title: title,
      days: days,
      activatedAt: now,
      tripStartDate: DateTime(now.year, now.month, now.day),
    );
    _lastStatus = _activeTrip!.status;
    _persist(); // fire-and-forget; failure is non-fatal
    _startTimer();
    notifyListeners();
  }

  /// Ends the active trip, clears persistence, and cancels the refresh timer.
  ///
  /// Call this on explicit user action (End Trip / Dismiss) or on logout.
  void endTrip() {
    _stopTimer();
    _activeTrip = null;
    _lastStatus = null;
    _clearPersistence(); // fire-and-forget
    notifyListeners();
  }

  // ── Timer ───────────────────────────────────────────────────────────────────

  /// Starts a 1-minute polling loop that notifies listeners only when
  /// [TripStatus] actually changes — prevents unnecessary rebuilds.
  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_activeTrip == null) {
        _stopTimer();
        return;
      }
      final newStatus = _activeTrip!.status;
      if (newStatus != _lastStatus) {
        _lastStatus = newStatus;
        notifyListeners();
      }
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Persists the minimum fields needed to reconstruct [ActiveTrip].
  ///
  /// Only [title], [activatedAt], and [tripStartDate] are stored.
  /// The [days] list is reconstructed from [TripPlannerMockData] on restore.
  ///
  /// When real trip data is stored server-side, replace this with a Supabase
  /// upsert keyed on the user's trip ID.
  Future<void> _persist() async {
    if (_activeTrip == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait(<Future<bool>>[
        prefs.setString(_kTitle, _activeTrip!.title),
        prefs.setString(_kActivatedAt, _activeTrip!.activatedAt.toIso8601String()),
        prefs.setString(_kTripStartDate, _activeTrip!.tripStartDate.toIso8601String()),
      ]);
    } catch (e) {
      debugPrint('TripStore._persist: failed — $e');
    }
  }

  Future<void> _clearPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait(<Future<bool>>[
        prefs.remove(_kTitle),
        prefs.remove(_kActivatedAt),
        prefs.remove(_kTripStartDate),
      ]);
    } catch (e) {
      debugPrint('TripStore._clearPersistence: failed — $e');
    }
  }
}
