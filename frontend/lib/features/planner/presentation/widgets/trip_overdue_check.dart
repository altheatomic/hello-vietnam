import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';

enum _OverdueDialogAction { notYet, openItinerary, markCompleted }

/// Client-pull check for trips left un-ended long after their planned end
/// date (Option B — no push/pg_cron yet).
///
/// Backed by cf_service's `get_overdue_plans()`, a pure query function kept
/// free of HTTP concerns so a future pg_cron/Scheduled-Edge-Function upgrade
/// (Option A) can call the exact same logic without a rewrite — only the
/// caller changes.
///
/// Call this once per Home open, after the user is known to be signed in.
/// This is the ONLY place that should call it — tapping the corresponding
/// bell notification deliberately does not re-trigger this dialog (see
/// NotificationActionHandler's tripOverdueCheck case), so it surfaces at
/// most once per app open, not on every notification tap.
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
  final String tripTitle = (trip.customTitle == null || trip.customTitle!.isEmpty)
      ? strings.ui('Your Vietnam Adventure')
      : trip.customTitle!;

  final _OverdueDialogAction? action = await showDialog<_OverdueDialogAction>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(strings.ui('Still on this trip?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tripTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${strings.ui('Have you completed your trip to')} '
            '${trip.provinceName}?',
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(_OverdueDialogAction.notYet),
          child: Text(strings.ui('Not yet')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(_OverdueDialogAction.openItinerary),
          child: Text(strings.ui('Open Itinerary')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(_OverdueDialogAction.markCompleted),
          child: Text(strings.ui('Mark as completed')),
        ),
      ],
    ),
  );

  switch (action) {
    case _OverdueDialogAction.markCompleted:
      try {
        await TripStore.instance.endTripByPlan(trip.idPlan);
      } catch (_) {
        // Non-fatal: the next Home open will offer the check again since
        // ended_at was never confirmed set server-side.
      }
      return;
    case _OverdueDialogAction.openItinerary:
      if (context.mounted) {
        context.push(AppRoutes.tripPlannerResultPath(idPlan: trip.idPlan));
      }
      return;
    case _OverdueDialogAction.notYet:
    case null:
      // Writes nothing: the plan stays overdue server-side, so the next
      // Home open will offer the check again until the trip is actually
      // completed (or ended via the bell notification's "End Trip" button).
      return;
  }
}
