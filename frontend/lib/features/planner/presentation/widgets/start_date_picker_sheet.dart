import 'package:flutter/material.dart';

import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';

/// Bottom sheet for picking a single new start date, built on top of the
/// shared [DateRangeCalendar] (which only exposes a *range* selection via
/// [DateRangeCalendar.onRangeChanged] — there is no single-date mode).
///
/// To reuse it without forking the widget: the sheet waits for a completed
/// range (which requires tapping a start day, then any later day to
/// confirm) and takes only `range.start` as the result — the end of that
/// range is discarded, since the caller computes its own end date from the
/// trip's original duration.
///
/// Returns the picked date, or null if the sheet was dismissed.
Future<DateTime?> pickNewStartDate(
  BuildContext context, {
  required DateTime firstSelectableDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sheetContext.l10n.ui('Select new start date'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(sheetContext).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sheetContext.l10n.ui(
                          'Tap your new start date, then tap any later date to confirm',
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Theme.of(
                            sheetContext,
                          ).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DateRangeCalendar(
                    firstDate: firstSelectableDate,
                    onRangeChanged: (DateTimeRange? range) {
                      if (range != null) {
                        Navigator.of(sheetContext).pop(range.start);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
