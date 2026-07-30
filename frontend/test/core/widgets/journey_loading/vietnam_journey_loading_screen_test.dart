import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/widgets/journey_loading/cloud_curtain.dart';
import 'package:hellovietnam/core/widgets/journey_loading/flying_crane_flock.dart';
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
    await tester.pump(const Duration(milliseconds: 10));

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

  testWidgets('covered cloud curtain has an opaque full-screen backdrop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CloudCurtain(
            phase: JourneyLoadingPhase.covered,
            reduceMotion: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('journey-cloud-coverage')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('journey-cloud-coverage'))),
      tester.getSize(find.byType(CloudCurtain)),
    );
  });

  testWidgets('cloud reveal uses the 1.2 second timeline window', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CloudCurtain(
          phase: JourneyLoadingPhase.revealing,
          reduceMotion: false,
        ),
      ),
    );

    expect(
      tester
          .widget<AnimatedSlide>(find.byKey(const Key('journey-cloud-left')))
          .duration,
      const Duration(milliseconds: 1200),
    );
  });

  testWidgets('crane exit completes within the timeline exit duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlyingCraneFlock(
          phase: JourneyLoadingPhase.exiting,
          reduceMotion: false,
        ),
      ),
    );

    expect(
      tester
          .widget<AnimatedSlide>(find.byKey(const Key('journey-crane-flock')))
          .duration,
      const Duration(milliseconds: 600),
    );
  });

  testWidgets('cloud exit completes within the timeline exit duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CloudCurtain(
          phase: JourneyLoadingPhase.exiting,
          reduceMotion: false,
        ),
      ),
    );

    expect(
      tester
          .widget<AnimatedSlide>(find.byKey(const Key('journey-cloud-left')))
          .duration,
      const Duration(milliseconds: 600),
    );
  });

  testWidgets('screen status fades out within the timeline exit duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VietnamJourneyLoadingScreen(
          message: 'Opening Hello Vietnam',
          isComplete: true,
          timelineFactory: _exitTimeline,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('journey-loading-exit')),
          )
          .duration,
      const Duration(milliseconds: 600),
    );
  });

  testWidgets('announces the loading message through one semantics node', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VietnamJourneyLoadingScreen(message: 'Opening Hello Vietnam'),
      ),
    );

    final liveRegion = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Opening Hello Vietnam',
    );
    expect(liveRegion, findsOneWidget);
    expect(tester.widget<Semantics>(liveRegion).excludeSemantics, isTrue);
  });

  testWidgets('compact loader remains usable at a constrained height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 260,
          child: VietnamJourneyLoadingScreen(
            message: 'Opening Hello Vietnam',
            compact: true,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('journey-crane-flock'))).width,
      180,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloud curtain tolerates a zero-size startup frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          child: SizedBox.shrink(
            child: CloudCurtain(
              phase: JourneyLoadingPhase.covered,
              reduceMotion: false,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('crane flock tolerates zero startup display metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(devicePixelRatio: 0),
          child: FlyingCraneFlock(
            phase: JourneyLoadingPhase.covered,
            reduceMotion: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('crane entrance starts beyond wide viewport right edges', (
    tester,
  ) async {
    for (final width in <double>[1024, 1440]) {
      await _craneBounds(
        tester,
        viewportWidth: width,
        phase: JourneyLoadingPhase.covered,
      );
      final bounds = await _craneBounds(
        tester,
        viewportWidth: width,
        phase: JourneyLoadingPhase.entering,
      );

      expect(
        bounds.crane.left,
        greaterThanOrEqualTo(bounds.viewport.right),
        reason: 'entrance origin must be offscreen at ${width}px',
      );
    }
  });

  testWidgets('crane exit finishes beyond wide viewport left edges', (
    tester,
  ) async {
    for (final width in <double>[1024, 1440]) {
      await _craneBounds(
        tester,
        viewportWidth: width,
        phase: JourneyLoadingPhase.waiting,
      );
      final bounds = await _craneBounds(
        tester,
        viewportWidth: width,
        phase: JourneyLoadingPhase.exiting,
        settle: const Duration(milliseconds: 600),
      );

      expect(
        bounds.crane.right,
        lessThanOrEqualTo(bounds.viewport.left),
        reason: 'exit destination must be offscreen at ${width}px',
      );
    }
  });

  testWidgets('crane flight keeps its phone-size offscreen bounds', (
    tester,
  ) async {
    final entrance = await _craneBounds(
      tester,
      viewportWidth: 390,
      phase: JourneyLoadingPhase.covered,
    );
    expect(entrance.crane.left, greaterThanOrEqualTo(entrance.viewport.right));

    final visible = await _craneBounds(
      tester,
      viewportWidth: 390,
      phase: JourneyLoadingPhase.waiting,
      settle: const Duration(milliseconds: 900),
    );
    final exit = await _craneBounds(
      tester,
      viewportWidth: 390,
      phase: JourneyLoadingPhase.exiting,
      settle: const Duration(milliseconds: 600),
    );
    expect(exit.crane.right, lessThanOrEqualTo(exit.viewport.left));
    expect(visible.crane.width, 290);
  });
}

JourneyLoadingTimeline _shortTimeline() => JourneyLoadingTimeline(
  minimumDuration: const Duration(milliseconds: 1),
  exitDuration: const Duration(milliseconds: 1),
);

JourneyLoadingTimeline _exitTimeline() =>
    JourneyLoadingTimeline(minimumDuration: const Duration(milliseconds: 1));

Future<({Rect crane, Rect viewport})> _craneBounds(
  WidgetTester tester, {
  required double viewportWidth,
  required JourneyLoadingPhase phase,
  Duration settle = Duration.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(viewportWidth, 800);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FlyingCraneFlock(
            key: ValueKey(viewportWidth),
            phase: phase,
            reduceMotion: false,
          ),
        ),
      ),
    ),
  );
  if (settle > Duration.zero) await tester.pump(settle);

  return (
    crane: tester.getRect(
      find.descendant(
        of: find.byKey(const Key('journey-crane-flock')),
        matching: find.byType(Image),
      ),
    ),
    viewport: tester.getRect(find.byType(Scaffold)),
  );
}
