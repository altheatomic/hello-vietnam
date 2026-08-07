import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/widgets/journey_loading/journey_loading_timeline.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/presentation/trip_result_page.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/trip_result_loader.dart';

void main() {
  testWidgets('shows the journey loader while a saved plan is pending', (
    tester,
  ) async {
    final loading = Completer<TripPlanResponse>();

    await tester.pumpWidget(
      _testApp(
        loadPlan: (_) => loading.future,
        timelineFactory: _shortTimeline,
      ),
    );

    expect(find.byType(VietnamJourneyLoadingScreen), findsOneWidget);
    expect(find.text('Preparing your Vietnam journey'), findsOneWidget);
    expect(find.byType(TripResultPage), findsNothing);
  });

  testWidgets('waits for the journey exit before showing a loaded plan', (
    tester,
  ) async {
    final loading = Completer<TripPlanResponse>();

    await tester.pumpWidget(
      _testApp(
        loadPlan: (_) => loading.future,
        timelineFactory: _shortTimeline,
      ),
    );

    loading.complete(_plan);
    await tester.pump();

    expect(
      tester
          .widget<VietnamJourneyLoadingScreen>(
            find.byType(VietnamJourneyLoadingScreen),
          )
          .isComplete,
      isTrue,
    );
    expect(find.byType(TripResultPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(TripResultPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(TripResultPage), findsOneWidget);
    expect(find.byType(VietnamJourneyLoadingScreen), findsNothing);
  });

  testWidgets('shows the existing error view without a success exit', (
    tester,
  ) async {
    final loading = Completer<TripPlanResponse>();

    await tester.pumpWidget(
      _testApp(
        loadPlan: (_) => loading.future,
        timelineFactory: _shortTimeline,
      ),
    );

    loading.completeError(StateError('load failed'));
    await tester.pump();

    expect(find.text('Could not load trip. Please try again.'), findsOneWidget);
    expect(find.byType(VietnamJourneyLoadingScreen), findsNothing);
    expect(find.byType(TripResultPage), findsNothing);
  });

  testWidgets(
    'ignores stale completions after the plan id changes away and back',
    (tester) async {
      final firstPlanA = Completer<TripPlanResponse>();
      final planB = Completer<TripPlanResponse>();
      final latestPlanA = Completer<TripPlanResponse>();
      var loadCount = 0;

      Future<TripPlanResponse> loadPlan(String idPlan) {
        loadCount++;
        return switch (loadCount) {
          1 => firstPlanA.future,
          2 => planB.future,
          _ => latestPlanA.future,
        };
      }

      await tester.pumpWidget(
        _testApp(
          idPlan: 'plan-a',
          loadPlan: loadPlan,
          timelineFactory: _shortTimeline,
        ),
      );
      await tester.pumpWidget(
        _testApp(
          idPlan: 'plan-b',
          loadPlan: loadPlan,
          timelineFactory: _shortTimeline,
        ),
      );
      await tester.pumpWidget(
        _testApp(
          idPlan: 'plan-a',
          loadPlan: loadPlan,
          timelineFactory: _shortTimeline,
        ),
      );

      firstPlanA.complete(
        const TripPlanResponse(idPlan: 'stale-plan-a', days: <TripPlanDay>[]),
      );
      await tester.pump();

      expect(
        tester
            .widget<VietnamJourneyLoadingScreen>(
              find.byType(VietnamJourneyLoadingScreen),
            )
            .isComplete,
        isFalse,
      );

      latestPlanA.complete(_plan);
      await tester.pump();

      expect(
        tester
            .widget<VietnamJourneyLoadingScreen>(
              find.byType(VietnamJourneyLoadingScreen),
            )
            .isComplete,
        isTrue,
      );
    },
  );

  testWidgets('does not update state when loading completes after disposal', (
    tester,
  ) async {
    final loading = Completer<TripPlanResponse>();

    await tester.pumpWidget(
      _testApp(
        loadPlan: (_) => loading.future,
        timelineFactory: _shortTimeline,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    loading.complete(_plan);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({
  String idPlan = 'plan-42',
  required TripPlanLoader loadPlan,
  required JourneyLoadingTimeline Function() timelineFactory,
}) {
  return MaterialApp(
    home: TripResultLoader(
      idPlan: idPlan,
      draft: null,
      loadPlan: loadPlan,
      timelineFactory: timelineFactory,
    ),
  );
}

JourneyLoadingTimeline _shortTimeline() {
  return JourneyLoadingTimeline(
    minimumDuration: const Duration(milliseconds: 20),
    exitDuration: const Duration(milliseconds: 20),
  );
}

const TripPlanResponse _plan = TripPlanResponse(
  idPlan: 'plan-42',
  days: <TripPlanDay>[],
);
