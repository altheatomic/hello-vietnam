import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/app.dart';
import 'package:hellovietnam/app/router.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(App(router: buildRouter()));
    await tester.pumpAndSettle();
    expect(find.byType(App), findsOneWidget);
  });
}
