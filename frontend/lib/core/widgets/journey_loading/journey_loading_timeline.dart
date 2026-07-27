import 'dart:async';

import 'package:flutter/foundation.dart';

enum JourneyLoadingPhase {
  covered,
  revealing,
  entering,
  waiting,
  exiting,
  complete,
}

class JourneyLoadingTimeline extends ChangeNotifier {
  JourneyLoadingTimeline({
    Duration minimumDuration = const Duration(milliseconds: 3200),
    Duration exitDuration = const Duration(milliseconds: 600),
  }) : _minimumDuration = minimumDuration,
       _exitDuration = exitDuration;

  static const _revealingAt = Duration(milliseconds: 300);
  static const _enteringAt = Duration(milliseconds: 1200);
  static const _waitingAt = Duration(milliseconds: 2100);

  final Duration _minimumDuration;
  final Duration _exitDuration;
  final Completer<void> _finishedCompleter = Completer<void>();

  JourneyLoadingPhase _phase = JourneyLoadingPhase.covered;
  bool _completionRequested = false;
  bool _started = false;
  Timer? _revealingTimer;
  Timer? _enteringTimer;
  Timer? _waitingTimer;
  Timer? _minimumTimer;
  Timer? _exitTimer;

  JourneyLoadingPhase get phase => _phase;

  bool get completionRequested => _completionRequested;

  Future<void> get finished => _finishedCompleter.future;

  void start() {
    if (_started) return;
    _started = true;

    _revealingTimer = Timer(
      _revealingAt,
      () => _setPhase(JourneyLoadingPhase.revealing),
    );
    _enteringTimer = Timer(
      _enteringAt,
      () => _setPhase(JourneyLoadingPhase.entering),
    );
    _waitingTimer = Timer(
      _waitingAt,
      () => _setPhase(JourneyLoadingPhase.waiting),
    );
    _minimumTimer = Timer(_minimumDuration, () {
      if (_completionRequested) _startExit();
    });
  }

  void markComplete() {
    _completionRequested = true;
    if (_started && _minimumTimer?.isActive == false) _startExit();
  }

  void _startExit() {
    if (_phase == JourneyLoadingPhase.exiting ||
        _phase == JourneyLoadingPhase.complete) {
      return;
    }

    _cancelPhaseTimers();
    _setPhase(JourneyLoadingPhase.exiting);
    _exitTimer = Timer(_exitDuration, () {
      _setPhase(JourneyLoadingPhase.complete);
      if (!_finishedCompleter.isCompleted) _finishedCompleter.complete();
    });
  }

  void _setPhase(JourneyLoadingPhase value) {
    if (_phase == value) return;
    _phase = value;
    notifyListeners();
  }

  void _cancelPhaseTimers() {
    _revealingTimer?.cancel();
    _enteringTimer?.cancel();
    _waitingTimer?.cancel();
    _minimumTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelPhaseTimers();
    _exitTimer?.cancel();
    super.dispose();
  }
}
