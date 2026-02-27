import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.byType(App), findsOneWidget);
  });
}
