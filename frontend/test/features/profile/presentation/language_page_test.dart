import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/features/profile/presentation/language_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('shows loading while applying language then returns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LanguagePage(),
                        ),
                      );
                    },
                    child: const Text('Open language'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open language'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguagePage), findsOneWidget);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Applying language...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(LanguagePage), findsNothing);
    expect(AppLanguageController.instance.language, AppLanguage.vietnamese);
  });

  testWidgets('stops loading after applying language when page cannot pop', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: const MaterialApp(home: LanguagePage()),
      ),
    );

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(LanguagePage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(AppLanguageController.instance.language, AppLanguage.vietnamese);
  });

  testWidgets('uses readable semantic text colors in dark mode', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(theme: darkTheme, home: const LanguagePage()),
      ),
    );

    final Text title = tester.widget<Text>(find.text('Language'));
    final Text subtitle = tester.widget<Text>(
      find.text('Select your preferred language'),
    );
    final Text languageName = tester.widget<Text>(find.text('English'));
    final Text languageDescription = tester.widget<Text>(
      find.text('App interface language'),
    );

    expect(title.style?.color, darkTheme.colorScheme.onSurface);
    expect(subtitle.style?.color, darkTheme.colorScheme.onSurfaceVariant);
    expect(languageName.style?.color, darkTheme.colorScheme.onSurface);
    expect(
      languageDescription.style?.color,
      darkTheme.colorScheme.onSurfaceVariant,
    );
  });
}
