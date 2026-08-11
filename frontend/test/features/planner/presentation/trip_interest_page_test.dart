import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/trip_interest_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Step 4 (Interest) only navigates to Step 5 (Budget/lunch-break page) now —
// it used to build the TripPlanRequest and generate the trip itself,
// silently skipping Step 5 entirely (see the lunch-break-step navigation
// audit). Generation coverage lives in trip_generation_loading_test.dart,
// against TripBudgetPage, which now owns the "Generate" action.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('Next pushes to the budget step carrying selected interests', (
    tester,
  ) async {
    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/interest',
      routes: <RouteBase>[
        GoRoute(
          path: '/interest',
          builder: (context, state) =>
              const TripInterestPage(wizard: _wizard),
        ),
        GoRoute(
          path: AppRoutes.tripPlannerBudget,
          builder: (context, state) {
            capturedExtra = state.extra;
            return const Scaffold(body: Text('budget destination'));
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

    await tester.tap(find.text('Culture & History'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('budget destination'), findsOneWidget);
    expect(capturedExtra, isA<Map<String, dynamic>>());
    final extra = capturedExtra! as Map<String, dynamic>;
    expect(extra['idProvince'], _wizard.idProvince);
    expect(extra['nDays'], _wizard.nDays);
    expect(extra['interestOptionIds'], <String>['culture_history']);
  });

  testWidgets('Next stays disabled until an interest is selected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(home: TripInterestPage(wizard: _wizard)),
      ),
    );
    await tester.pump();

    final InkWell nextButton = tester.widget(
      find.widgetWithText(InkWell, 'Next'),
    );
    expect(nextButton.onTap, isNull);
  });
}

const _wizard = TripWizardData(
  idProvince: 'province-1',
  nDays: 3,
  startDate: '2026-08-01',
  tripType: 'leisure',
);
