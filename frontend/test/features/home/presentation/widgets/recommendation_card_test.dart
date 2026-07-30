import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/home/presentation/widgets/recommendation_card.dart';

void main() {
  testWidgets('shows no-rating copy when the item has no reviews', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 240,
            child: RecommendationCard(
              name: 'Bun bo Hue',
              category: 'Food',
              rating: null,
              reviewCount: 0,
              imagePath: '',
            ),
          ),
        ),
      ),
    );

    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('shows a numeric rating only when reviews exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 240,
            child: RecommendationCard(
              name: 'Ha Tinh',
              category: 'Destination',
              rating: 4.75,
              reviewCount: 8,
              imagePath: '',
            ),
          ),
        ),
      ),
    );

    expect(find.text('4.75'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
