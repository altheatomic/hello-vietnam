import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
