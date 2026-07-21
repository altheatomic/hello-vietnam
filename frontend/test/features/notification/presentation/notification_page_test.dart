import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/features/notification/presentation/notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
  });

  testWidgets('shows notification UI and sample content in Vietnamese', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: const MaterialApp(home: NotificationPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Đà Lạt có lễ hội mới!'), findsOneWidget);
    expect(find.text('Đừng bỏ lỡ cơ hội tham gia Lễ hội Hoa.'), findsOneWidget);
    expect(find.text('9 ngày trước'), findsOneWidget);
  });

  testWidgets('uses a dark background gradient in dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const NotificationPage(),
        ),
      ),
    );
    await tester.pump();

    final Iterable<DecoratedBox> darkBackgrounds = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((DecoratedBox box) {
          final Decoration decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.gradient is LinearGradient &&
              (decoration.gradient! as LinearGradient).colors.first
                      .computeLuminance() <
                  0.1;
        });
    expect(darkBackgrounds, isNotEmpty);
  });
}
