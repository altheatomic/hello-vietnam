import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/app_bootstrap.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/core/widgets/app_loading_screen.dart';
import 'package:hellovietnam/core/widgets/journey_loading/journey_loading_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
  });

  setUp(() async {
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('uses persisted Vietnamese for the bootstrap journey message', (
    tester,
  ) async {
    final initialization = Completer<void>();
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);

    await tester.pumpWidget(
      AppBootstrap(
        initializeApp: () => initialization.future,
        readyBuilder: _readyBuilder,
        timelineFactory: _shortTimeline,
      ),
    );

    expect(find.text('Đang mở Hello Vietnam'), findsOneWidget);
    expect(find.text('Opening Hello Vietnam'), findsNothing);
  });

  testWidgets('shows the animated loader while initialization is pending', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      AppBootstrap(
        initializeApp: () => initialization.future,
        readyBuilder: _readyBuilder,
        timelineFactory: _shortTimeline,
      ),
    );

    expect(find.byKey(const Key('journey-loading-screen')), findsOneWidget);
    expect(find.byKey(const Key('bootstrap-ready')), findsNothing);
    expect(
      tester.widget<AppLoadingScreen>(find.byType(AppLoadingScreen)).isComplete,
      isFalse,
    );
  });

  testWidgets('waits for the loading exit after initialization succeeds', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      AppBootstrap(
        initializeApp: () => initialization.future,
        readyBuilder: _readyBuilder,
        timelineFactory: _shortTimeline,
      ),
    );

    initialization.complete();
    await tester.pump();

    expect(
      tester.widget<AppLoadingScreen>(find.byType(AppLoadingScreen)).isComplete,
      isTrue,
    );
    expect(find.byKey(const Key('bootstrap-ready')), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('bootstrap-ready')), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('bootstrap-ready')), findsOneWidget);
    expect(find.byType(AppLoadingScreen), findsNothing);
  });

  testWidgets(
    'shows initialization errors without waiting for a success exit',
    (tester) async {
      final initialization = Completer<void>();

      await tester.pumpWidget(
        AppBootstrap(
          initializeApp: () => initialization.future,
          readyBuilder: _readyBuilder,
          timelineFactory: _shortTimeline,
        ),
      );

      initialization.completeError(StateError('bootstrap failed'));
      await tester.pump();

      expect(find.text('Unable to start the app'), findsOneWidget);
      expect(find.textContaining('bootstrap failed'), findsOneWidget);
      expect(find.byKey(const Key('journey-loading-screen')), findsNothing);
      expect(find.byKey(const Key('bootstrap-ready')), findsNothing);
    },
  );

  testWidgets('retry resets readiness and waits for the new loading exit', (
    tester,
  ) async {
    final retryInitialization = Completer<void>();
    var attempts = 0;

    Future<void> initialize() {
      attempts++;
      if (attempts == 1) {
        return Future<void>.error(StateError('first attempt failed'));
      }
      return retryInitialization.future;
    }

    await tester.pumpWidget(
      AppBootstrap(
        initializeApp: initialize,
        readyBuilder: _readyBuilder,
        timelineFactory: _shortTimeline,
      ),
    );
    await tester.pump();

    expect(find.text('Unable to start the app'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.byKey(const Key('journey-loading-screen')), findsOneWidget);
    expect(
      tester.widget<AppLoadingScreen>(find.byType(AppLoadingScreen)).isComplete,
      isFalse,
    );
    expect(find.byKey(const Key('bootstrap-ready')), findsNothing);

    retryInitialization.complete();
    await tester.pump();

    expect(
      tester.widget<AppLoadingScreen>(find.byType(AppLoadingScreen)).isComplete,
      isTrue,
    );
    expect(find.byKey(const Key('bootstrap-ready')), findsNothing);

    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const Key('bootstrap-ready')), findsOneWidget);
  });
}

Widget _readyBuilder(BuildContext context) {
  return const SizedBox(key: Key('bootstrap-ready'));
}

JourneyLoadingTimeline _shortTimeline() {
  return JourneyLoadingTimeline(
    minimumDuration: const Duration(milliseconds: 20),
    exitDuration: const Duration(milliseconds: 20),
  );
}
