import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/auth/presentation/register_page.dart';

void main() {
  testWidgets('Google button starts OAuth from the signup screen', (
    WidgetTester tester,
  ) async {
    int calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          googleSignIn: () async {
            calls += 1;
          },
        ),
      ),
    );

    final Finder googleButton = find.text('Continue with Google');
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Google Sign-In is handled in Login page'), findsNothing);
  });

  testWidgets('Google OAuth failure shows a red user-facing message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          googleSignIn: () async {
            throw Exception('technical provider details');
          },
        ),
      ),
    );

    final Finder googleButton = find.text('Continue with Google');
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pump();

    expect(find.text('Google sign in failed'), findsOneWidget);
    expect(find.textContaining('technical provider details'), findsNothing);

    final Color expectedErrorColor = Theme.of(
      tester.element(find.byType(RegisterPage)),
    ).colorScheme.error;
    final SnackBar snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, expectedErrorColor);
  });
}
