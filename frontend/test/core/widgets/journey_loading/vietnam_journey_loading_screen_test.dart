import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/widgets/journey_loading/journey_loading_timeline.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';

void main() {
  testWidgets('renders the cloud curtain, crane flock, and loading message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VietnamJourneyLoadingScreen(message: 'Opening Hello Vietnam'),
      ),
    );

    expect(find.byKey(const Key('journey-loading-screen')), findsOneWidget);
    expect(find.byKey(const Key('journey-cloud-left')), findsOneWidget);
    expect(find.byKey(const Key('journey-cloud-right')), findsOneWidget);
    expect(find.byKey(const Key('journey-crane-flock')), findsOneWidget);
    expect(find.text('Opening Hello Vietnam'), findsOneWidget);
  });

  testWidgets('calls the exit callback once after a completed short timeline', (
    tester,
  ) async {
    var exitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: VietnamJourneyLoadingScreen(
          message: 'Opening Hello Vietnam',
          isComplete: true,
          onExitComplete: () => exitCount++,
          timelineFactory: _shortTimeline,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 3));
    await tester.pump();

    expect(exitCount, 1);
  });

  testWidgets(
    'uses the reduced-motion composition when animations are disabled',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: VietnamJourneyLoadingScreen(message: 'Opening Hello Vietnam'),
          ),
        ),
      );

      expect(
        find.byKey(const Key('journey-loading-reduced-motion')),
        findsOneWidget,
      );
    },
  );
}

JourneyLoadingTimeline _shortTimeline() => JourneyLoadingTimeline(
  minimumDuration: const Duration(milliseconds: 1),
  exitDuration: const Duration(milliseconds: 1),
);
