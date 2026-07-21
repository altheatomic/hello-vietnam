import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/ai_search/presentation/ai_search_page.dart';

void main() {
  testWidgets('AI search uses the dark app background', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const AiSearchPage()),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, darkTheme.scaffoldBackgroundColor);

    final Iterable<Container> darkBackgrounds = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (Container item) => item.color == darkTheme.scaffoldBackgroundColor,
        );
    expect(darkBackgrounds, isNotEmpty);
  });
}
