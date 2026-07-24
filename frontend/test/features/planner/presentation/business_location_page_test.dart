import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/business_location_page.dart';
import 'package:hellovietnam/features/planner/presentation/trip_duration_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('renders the business location form without layout errors', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: const MaterialApp(home: BusinessLocationPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter address'), findsOneWidget);
    expect(find.text('e.g. District 1, Ho Chi Minh City'), findsOneWidget);
  });

  testWidgets('business trips use the shared leisure calendar layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: const MaterialApp(
          home: TripDurationPage(
            wizard: TripWizardData(
              tripType: 'business',
              businessAddress: 'District 1, Ho Chi Minh City',
              targetLat: 10.7756,
              targetLng: 106.7019,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DateRangeCalendar), findsOneWidget);
  });
}
