import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_request.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/trip_budget_page.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Budget (Step 5) is the only wizard step that generates a trip — Interest
// (Step 4) just navigates here now, see trip_interest_page_test.dart for its
// navigation-only coverage. This file used to also cover an "interest
// generation" path that no longer exists (Interest previously generated the
// trip directly and skipped this step entirely — see the lunch-break-step
// navigation audit/fix).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets(
    'budget generation waits for exit and opens the persisted result once',
    (tester) async {
      final generation = Completer<TripPlanResponse>();
      var generationCalls = 0;
      final harness = await _pumpBudgetPage(
        tester,
        generateTrip: (request) {
          generationCalls++;
          return generation.future;
        },
      );

      await tester.tap(find.text('Generate'));
      await tester.tap(find.text('Generate'));
      await tester.pump();

      expect(generationCalls, 1);
      expect(find.byType(VietnamJourneyLoadingScreen), findsOneWidget);
      expect(find.byType(PlannerStepScaffold), findsNothing);
      expect(
        find.text('Generating your personalised itinerary…'),
        findsOneWidget,
      );

      generation.complete(_persistedPlan);
      await tester.pump();

      final loader = tester.widget<VietnamJourneyLoadingScreen>(
        find.byType(VietnamJourneyLoadingScreen),
      );
      expect(loader.isComplete, isTrue);
      expect(harness.resultVisits, 0);

      loader.onExitComplete!();
      loader.onExitComplete!();
      await tester.pumpAndSettle();

      expect(harness.resultVisits, 1);
      expect(
        harness.resultUri,
        Uri.parse('/trip-planner/result?idPlan=budget-plan'),
      );
      expect(harness.resultExtra, same(_persistedPlan));
    },
  );

  testWidgets('budget generation failure immediately restores the form', (
    tester,
  ) async {
    final generation = Completer<TripPlanResponse>();
    await _pumpBudgetPage(tester, generateTrip: (request) => generation.future);

    await tester.tap(find.text('Generate'));
    await tester.pump();
    expect(find.byType(VietnamJourneyLoadingScreen), findsOneWidget);

    generation.completeError(StateError('generation failed'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(VietnamJourneyLoadingScreen), findsNothing);
    expect(find.byType(PlannerStepScaffold), findsOneWidget);
    expect(
      find.text('Could not generate your trip. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('ignores a generation completed for replaced planner inputs', (
    tester,
  ) async {
    final generation = Completer<TripPlanResponse>();
    await _pumpDirectBudgetPage(
      tester,
      wizard: _wizard,
      generateTrip: (request) => generation.future,
    );

    await tester.tap(find.text('Generate'));
    await tester.pump();
    expect(find.byType(VietnamJourneyLoadingScreen), findsOneWidget);

    await _pumpDirectBudgetPage(
      tester,
      wizard: _replacementWizard,
      generateTrip: (request) => generation.future,
    );
    expect(find.byType(VietnamJourneyLoadingScreen), findsNothing);
    expect(find.byType(PlannerStepScaffold), findsOneWidget);

    generation.complete(_persistedPlan);
    await tester.pump();

    expect(find.byType(VietnamJourneyLoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores generation completion after the planner is disposed', (
    tester,
  ) async {
    final generation = Completer<TripPlanResponse>();
    await _pumpDirectBudgetPage(
      tester,
      wizard: _wizard,
      generateTrip: (request) => generation.future,
    );

    await tester.tap(find.text('Generate'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    generation.complete(_persistedPlan);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps budget generation active for value-equal wizard data', (
    tester,
  ) async {
    final generation = Completer<TripPlanResponse>();
    await _pumpDirectBudgetPage(
      tester,
      wizard: _wizard,
      generateTrip: (request) => generation.future,
    );

    await tester.tap(find.text('Generate'));
    await tester.pump();

    await _pumpDirectBudgetPage(
      tester,
      wizard: _equalWizardCopy(),
      generateTrip: (request) => generation.future,
    );
    expect(find.byType(VietnamJourneyLoadingScreen), findsOneWidget);

    generation.complete(_persistedPlan);
    await tester.pump();

    expect(
      tester
          .widget<VietnamJourneyLoadingScreen>(
            find.byType(VietnamJourneyLoadingScreen),
          )
          .isComplete,
      isTrue,
    );
  });
}

Future<_PlannerHarness> _pumpBudgetPage(
  WidgetTester tester, {
  required Future<TripPlanResponse> Function(TripPlanRequest request)
  generateTrip,
}) {
  return _pumpPlannerPage(
    tester,
    initialLocation: '/budget',
    pageBuilder: () =>
        TripBudgetPage(wizard: _wizard, generateTrip: generateTrip),
  );
}

Future<_PlannerHarness> _pumpPlannerPage(
  WidgetTester tester, {
  required String initialLocation,
  required Widget Function() pageBuilder,
}) async {
  final harness = _PlannerHarness();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/budget', builder: (context, state) => pageBuilder()),
      GoRoute(
        path: AppRoutes.tripPlannerResult,
        builder: (context, state) {
          harness
            ..resultVisits = harness.resultVisits + 1
            ..resultUri = state.uri
            ..resultExtra = state.extra;
          return const Scaffold(body: Text('trip result destination'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppLanguageScope(
      controller: AppLanguageController.instance,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _pumpDirectBudgetPage(
  WidgetTester tester, {
  required TripWizardData wizard,
  required Future<TripPlanResponse> Function(TripPlanRequest request)
  generateTrip,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppLanguageScope(
      controller: AppLanguageController.instance,
      child: MaterialApp(
        home: TripBudgetPage(wizard: wizard, generateTrip: generateTrip),
      ),
    ),
  );
  await tester.pump();
}

class _PlannerHarness {
  int resultVisits = 0;
  Uri? resultUri;
  Object? resultExtra;
}

const _wizard = TripWizardData(
  idProvince: 'province-1',
  nDays: 3,
  startDate: '2026-08-01',
  tripType: 'leisure',
);

const _replacementWizard = TripWizardData(
  idProvince: 'province-2',
  nDays: 5,
  startDate: '2026-09-01',
  tripType: 'leisure',
);

TripWizardData _equalWizardCopy() => TripWizardData(
  idProvince: _wizard.idProvince,
  provinceName: _wizard.provinceName,
  nDays: _wizard.nDays,
  startDate: _wizard.startDate,
  tripType: _wizard.tripType,
  targetLat: _wizard.targetLat,
  targetLng: _wizard.targetLng,
  businessAddress: _wizard.businessAddress,
);

const _persistedPlan = TripPlanResponse(
  idPlan: 'budget-plan',
  days: <TripPlanDay>[],
);
