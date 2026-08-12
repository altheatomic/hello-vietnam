import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/trip_overdue_check.dart';

/// Overrides checkOverdueTrips() only — no network call, no Supabase client.
class _FakeOverdueTripRepository extends TripRepository {
  _FakeOverdueTripRepository(this._plans);

  final List<OverdueTripPlan> _plans;

  @override
  Future<List<OverdueTripPlan>> checkOverdueTrips() async => _plans;
}

void main() {
  testWidgets(
    'overdue dialog shows title, trip name, and 3 full-width stacked buttons '
    '— no "Have you completed" line',
    (WidgetTester tester) async {
      final repo = _FakeOverdueTripRepository(<OverdueTripPlan>[
        const OverdueTripPlan(
          idPlan: 'plan-1',
          customTitle: 'Da Lat Getaway',
          startAt: '2026-07-01',
          endAt: '2026-07-05',
          provinceName: '',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => checkOverdueTrip(context, repository: repo),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      // Title + trip name present.
      expect(find.text('Completed this trip?'), findsOneWidget);
      expect(find.text('Da Lat Getaway'), findsOneWidget);

      // The removed line must not appear in any form.
      expect(find.textContaining('Have you completed'), findsNothing);

      // All 3 actions present, rendered as their expected button types.
      expect(find.widgetWithText(TextButton, 'Not yet'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Open Itinerary'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Mark as completed'),
        findsOneWidget,
      );

      // Each button is wrapped full-width (SizedBox.width == double.infinity)
      // so they stack consistently instead of relying on OverflowBar.
      for (final Type buttonType in <Type>[
        TextButton,
        OutlinedButton,
        FilledButton,
      ]) {
        final Finder wrapper = find.ancestor(
          of: find.byType(buttonType),
          matching: find.byType(SizedBox),
        );
        final SizedBox box = tester.widget<SizedBox>(wrapper.first);
        expect(box.width, double.infinity);
      }

      // No default AlertDialog OverflowBar/actions row involved.
      final AlertDialog dialog = tester.widget<AlertDialog>(
        find.byType(AlertDialog),
      );
      expect(dialog.actions, isNull);
    },
  );
}
