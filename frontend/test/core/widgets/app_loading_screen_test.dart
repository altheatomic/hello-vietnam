import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/app_loading_screen.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';

void main() {
  testWidgets('uses the journey loader for a full-screen loading state', (
    tester,
  ) async {
    var exited = false;
    void onExitComplete() => exited = true;

    await tester.pumpWidget(
      MaterialApp(
        home: AppLoadingScreen(
          message: 'Opening Hello Vietnam',
          isComplete: true,
          onExitComplete: onExitComplete,
        ),
      ),
    );

    final journeyLoader = tester.widget<VietnamJourneyLoadingScreen>(
      find.byType(VietnamJourneyLoadingScreen),
    );
    expect(journeyLoader.message, 'Opening Hello Vietnam');
    expect(journeyLoader.isComplete, isTrue);
    expect(journeyLoader.onExitComplete, same(onExitComplete));
    expect(exited, isFalse);
  });

  testWidgets('keeps compact loading panel free of journey visual assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppLoadingScreen(message: 'Loading profile', compact: true),
      ),
    );

    expect(find.byType(VietnamJourneyLoadingScreen), findsNothing);
    expect(find.byKey(const Key('journey-cloud-left')), findsNothing);
    expect(find.byKey(const Key('journey-cloud-right')), findsNothing);
    expect(find.byKey(const Key('journey-crane-flock')), findsNothing);
    expect(find.text('Loading profile'), findsOneWidget);
  });

  test('translates Vietnam journey loading messages into Vietnamese', () {
    final strings = AppStrings.of(AppLanguage.vietnamese);

    expect(strings.ui('Opening Hello Vietnam'), 'Đang mở Hello Vietnam');
    expect(
      strings.ui('Preparing your Vietnam journey'),
      'Đang chuẩn bị hành trình Việt Nam',
    );
    expect(
      strings.ui('Generating your personalised itinerary…'),
      'Đang tạo lịch trình dành riêng cho bạn…',
    );
  });
}
