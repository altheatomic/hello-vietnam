import 'package:flutter/material.dart';

import 'cloud_curtain.dart';
import 'flying_crane_flock.dart';
import 'journey_loading_timeline.dart';

class VietnamJourneyLoadingScreen extends StatefulWidget {
  const VietnamJourneyLoadingScreen({
    super.key,
    required this.message,
    this.isComplete = false,
    this.onExitComplete,
    this.compact = false,
    this.timelineFactory,
  });

  final String message;
  final bool isComplete;
  final VoidCallback? onExitComplete;
  final bool compact;
  final JourneyLoadingTimeline Function()? timelineFactory;

  @override
  State<VietnamJourneyLoadingScreen> createState() =>
      _VietnamJourneyLoadingScreenState();
}

class _VietnamJourneyLoadingScreenState
    extends State<VietnamJourneyLoadingScreen> {
  late final JourneyLoadingTimeline _timeline;
  var _exitNotified = false;

  @override
  void initState() {
    super.initState();
    _timeline = widget.timelineFactory?.call() ?? JourneyLoadingTimeline();
    _timeline.addListener(_onTimelineChanged);
    _timeline.finished.then((_) {
      if (mounted && !_exitNotified) {
        _exitNotified = true;
        widget.onExitComplete?.call();
      }
    });
    _timeline.start();
    if (widget.isComplete) _timeline.markComplete();
  }

  @override
  void didUpdateWidget(covariant VietnamJourneyLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete && !oldWidget.isComplete) _timeline.markComplete();
  }

  void _onTimelineChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timeline
      ..removeListener(_onTimelineChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final isExiting =
        _timeline.phase == JourneyLoadingPhase.exiting ||
        _timeline.phase == JourneyLoadingPhase.complete;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surfaceContainerHighest.withValues(alpha: .62),
                colorScheme.primaryContainer.withValues(alpha: .78),
              ],
            ),
          ),
        ),
        CloudCurtain(phase: _timeline.phase, reduceMotion: reduceMotion),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FlyingCraneFlock(
                    phase: _timeline.phase,
                    reduceMotion: reduceMotion,
                    compact: widget.compact,
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    liveRegion: true,
                    label: widget.message,
                    excludeSemantics: true,
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return Semantics(
      key: const Key('journey-loading-screen'),
      container: true,
      child: AnimatedOpacity(
        key: const Key('journey-loading-exit'),
        duration: Duration(milliseconds: reduceMotion ? 120 : 600),
        curve: Curves.easeInOut,
        opacity: isExiting ? 0 : 1,
        child: reduceMotion
            ? KeyedSubtree(
                key: const Key('journey-loading-reduced-motion'),
                child: content,
              )
            : content,
      ),
    );
  }
}
