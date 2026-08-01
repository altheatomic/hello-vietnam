import 'package:flutter/material.dart';

import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';

/// Client-pull check for trips left un-ended long after their planned end
/// date (Option B — no push/pg_cron yet).
///
/// Backed by cf_service's `get_overdue_plans()`, a pure query function kept
/// free of HTTP concerns so a future pg_cron/Scheduled-Edge-Function upgrade
/// (Option A) can call the exact same logic without a rewrite — only the
/// caller changes.
///
/// Call this once per Home open, after the user is known to be signed in.
Future<void> checkOverdueTrip(
  BuildContext context, {
  TripRepository? repository,
}) async {
  final TripRepository repo = repository ?? TripRepository();

  List<OverdueTripPlan> overdue;
  try {
    overdue = await repo.checkOverdueTrips();
  } catch (_) {
    return; // best-effort background check — never surface this failure
  }
  if (overdue.isEmpty || !context.mounted) return;

  final OverdueTripPlan trip = overdue.first;
  final AppStrings strings = AppStrings.of(AppLanguageController.instance.language);

  final bool? markCompleted = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(strings.ui('Still on this trip?')),
      content: Text(
        '${strings.ui('Have you completed your trip to')} '
        '${trip.provinceName}?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(strings.ui('Not yet')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(strings.ui('Mark as completed')),
        ),
      ],
    ),
  );

  if (markCompleted == true) {
    try {
      await repo.completeTrip(trip.idPlan);
    } catch (_) {
      // Non-fatal: the next Home open will offer the check again since
      // ended_at was never set server-side.
    }
    if (TripStore.instance.activeTrip?.idPlan == trip.idPlan) {
      TripStore.instance.endTrip();
    }
  } else {
    try {
      await repo.markTripOverdueNotified(trip.idPlan);
    } catch (_) {
      // Non-fatal: worst case the user is asked again next time.
    }
  }
}
