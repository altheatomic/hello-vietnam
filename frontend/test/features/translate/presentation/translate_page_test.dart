import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/translate/presentation/translate_page.dart';

void main() {
  testWidgets('typing does not start translation until the user confirms', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TranslatePage()));

    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.pump();

    expect(find.text('Translating...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('uses the dark scaffold and semantic surfaces', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const TranslatePage()),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, darkTheme.scaffoldBackgroundColor);
    expect(
      tester.widgetList<Container>(find.byType(Container)).where((
        Container item,
      ) {
        final Decoration? decoration = item.decoration;
        return decoration is BoxDecoration &&
            decoration.color == darkTheme.colorScheme.surface;
      }),
      isNotEmpty,
    );
  });
}
