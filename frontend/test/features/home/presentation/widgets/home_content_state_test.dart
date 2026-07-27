import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/home/presentation/widgets/home_content_state.dart';

void main() {
  testWidgets('error state invokes retry when tapped', (
    WidgetTester tester,
  ) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeContentError(
            message: 'Could not load content',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('home-content-retry')));

    expect(retried, isTrue);
  });

  testWidgets('skeleton exposes a stable loading key', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeRecommendationSkeleton(
            key: Key('home-destinations-loading'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('home-destinations-loading')), findsOneWidget);
  });
}
