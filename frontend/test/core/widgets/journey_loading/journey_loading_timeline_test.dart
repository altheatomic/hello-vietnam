// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/widgets/journey_loading/journey_loading_timeline.dart';

void main() {
  test('early completion waits for the 3.2 second minimum', () {
    fakeAsync((async) {
      final timeline = JourneyLoadingTimeline()..start();
      timeline.markComplete();

      async.elapse(const Duration(milliseconds: 3199));
      expect(timeline.phase, isNot(JourneyLoadingPhase.exiting));

      async.elapse(const Duration(milliseconds: 1));
      expect(timeline.phase, JourneyLoadingPhase.exiting);
      timeline.dispose();
    });
  });

  test('late completion exits immediately', () {
    fakeAsync((async) {
      final timeline = JourneyLoadingTimeline()..start();

      async.elapse(const Duration(seconds: 5));
      expect(timeline.phase, JourneyLoadingPhase.waiting);

      timeline.markComplete();
      expect(timeline.phase, JourneyLoadingPhase.exiting);
      timeline.dispose();
    });
  });

  test('finished completes once after the exit duration', () {
    fakeAsync((async) {
      final timeline = JourneyLoadingTimeline()..start();
      var completionCount = 0;
      timeline.finished.then((_) => completionCount++);

      timeline.markComplete();
      async.elapse(const Duration(milliseconds: 3799));
      expect(timeline.phase, JourneyLoadingPhase.exiting);
      expect(completionCount, 0);

      async.elapse(const Duration(milliseconds: 1));
      expect(timeline.phase, JourneyLoadingPhase.complete);
      expect(completionCount, 1);
      timeline.dispose();
    });
  });

  test('exit phase is not replaced by a pending phase timer', () {
    fakeAsync((async) {
      final timeline = JourneyLoadingTimeline(
        minimumDuration: const Duration(milliseconds: 100),
      )..start();
      timeline.markComplete();

      async.elapse(const Duration(milliseconds: 100));
      expect(timeline.phase, JourneyLoadingPhase.exiting);

      async.elapse(const Duration(milliseconds: 200));
      expect(timeline.phase, JourneyLoadingPhase.exiting);
      timeline.dispose();
    });
  });
}
