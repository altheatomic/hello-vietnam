import 'package:flutter/material.dart';

import 'journey_loading_timeline.dart';

class FlyingCraneFlock extends StatefulWidget {
  const FlyingCraneFlock({
    super.key,
    required this.phase,
    required this.reduceMotion,
    this.compact = false,
  });

  final JourneyLoadingPhase phase;
  final bool reduceMotion;
  final bool compact;

  @override
  State<FlyingCraneFlock> createState() => _FlyingCraneFlockState();
}

class _FlyingCraneFlockState extends State<FlyingCraneFlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _syncHover();
  }

  @override
  void didUpdateWidget(covariant FlyingCraneFlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHover();
  }

  void _syncHover() {
    if (widget.phase == JourneyLoadingPhase.waiting && !widget.reduceMotion) {
      _hoverController.repeat(reverse: true);
    } else {
      _hoverController.stop();
      _hoverController.value = 0;
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVisible =
        widget.phase == JourneyLoadingPhase.entering ||
        widget.phase == JourneyLoadingPhase.waiting;
    final isExiting =
        widget.phase == JourneyLoadingPhase.exiting ||
        widget.phase == JourneyLoadingPhase.complete;
    final duration = widget.reduceMotion
        ? const Duration(milliseconds: 120)
        : (isExiting
              ? const Duration(milliseconds: 600)
              : const Duration(milliseconds: 900));

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          widget.reduceMotion ? 0 : -8 * _hoverController.value,
        ),
        child: child,
      ),
      child: AnimatedSlide(
        key: const Key('journey-crane-flock'),
        duration: duration,
        curve: Curves.easeInOutCubic,
        offset: isExiting
            ? const Offset(-1.3, .18)
            : (isVisible
                  ? Offset.zero
                  : (widget.reduceMotion
                        ? const Offset(.08, -.04)
                        : const Offset(1.2, -.55))),
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeInOutCubic,
          scale: isVisible ? 1 : .86,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeInOut,
            opacity: isVisible ? 1 : 0,
            child: SizedBox(
              width: widget.compact ? 180 : 290,
              child: Image.asset(
                'assets/images/loading/vietnam_crane_flock.png',
                fit: BoxFit.contain,
                cacheWidth:
                    ((widget.compact ? 180 : 290) *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
