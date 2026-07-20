import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
  });

  testWidgets('localizes calendar labels when app language is Vietnamese', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 620,
              child: DateRangeCalendar(onRangeChanged: (_) {}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Chọn ngày đi'), findsOneWidget);
    expect(find.text('Chọn ngày'), findsOneWidget);
    expect(find.text('Tháng 1'), findsOneWidget);
    expect(find.text('CN'), findsWidgets);
  });
}
