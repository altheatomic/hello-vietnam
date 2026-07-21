import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/explore/presentation/widgets/explore_favorite_icon.dart';

void main() {
  testWidgets('uses red for an active Explore favorite', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ExploreFavoriteIcon(isFavorite: true)),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.favorite));
    expect(icon.color, const Color(0xFFFF5E7A));
  });

  testWidgets('keeps an inactive Explore favorite white', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ExploreFavoriteIcon(isFavorite: false)),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.favorite_border));
    expect(icon.color, Colors.white);
  });
}
