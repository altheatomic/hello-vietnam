import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/profile/presentation/currency_page.dart';

void main() {
  testWidgets('currency header text stays readable in dark mode', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const CurrencyPage()),
    );

    final Text title = tester.widget<Text>(find.text('Currency'));
    final Text subtitle = tester.widget<Text>(
      find.text('Select your preferred currency'),
    );

    expect(title.style?.color, darkTheme.colorScheme.onSurface);
    expect(subtitle.style?.color, darkTheme.colorScheme.onSurfaceVariant);
  });
}
