import 'package:flutter/material.dart';

import 'journey_loading_timeline.dart';

class CloudCurtain extends StatelessWidget {
  const CloudCurtain({
    super.key,
    required this.phase,
    required this.reduceMotion,
  });

  final JourneyLoadingPhase phase;
  final bool reduceMotion;

  static const _leftAsset = 'assets/images/loading/vietnam_cloud_left.png';
  static const _rightAsset = 'assets/images/loading/vietnam_cloud_right.png';
  static const _backAsset = 'assets/images/loading/vietnam_cloud_back.png';
  static const _fullMotionDuration = Duration(milliseconds: 1200);
  static const _reducedMotionDuration = Duration(milliseconds: 120);
  static const _exitDuration = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context) {
    final isCovered = phase == JourneyLoadingPhase.covered;
    final isExiting =
        phase == JourneyLoadingPhase.exiting ||
        phase == JourneyLoadingPhase.complete;
    final duration = reduceMotion
        ? _reducedMotionDuration
        : (isExiting ? _exitDuration : _fullMotionDuration);
    final curve = reduceMotion ? Curves.easeOut : Curves.easeInOutCubic;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: duration,
                  curve: curve,
                  opacity: isCovered ? 1 : 0,
                  child: DecoratedBox(
                    key: const Key('journey-cloud-coverage'),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D8798), Color(0xFF1EB8C2)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: height * .08,
                left: -width * .12,
                width: width * 1.24,
                child: AnimatedSlide(
                  duration: duration,
                  curve: curve,
                  offset: isCovered
                      ? Offset.zero
                      : Offset(reduceMotion ? 0 : -.16, -.08),
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: curve,
                    opacity: isCovered ? .88 : (isExiting ? 0 : .42),
                    child: _asset(
                      _backAsset,
                      cacheWidth: _cacheWidth(context, width * 1.24),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -height * .02,
                left: -width * .06,
                width: width * .82,
                child: AnimatedSlide(
                  key: const Key('journey-cloud-left'),
                  duration: duration,
                  curve: curve,
                  offset: isCovered
                      ? Offset.zero
                      : Offset(reduceMotion ? -.08 : -1.08, .02),
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: curve,
                    opacity: isExiting ? 0 : 1,
                    child: _asset(
                      _leftAsset,
                      cacheWidth: _cacheWidth(context, width * .82),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -width * .06,
                bottom: -height * .03,
                width: width * .82,
                child: AnimatedSlide(
                  key: const Key('journey-cloud-right'),
                  duration: duration,
                  curve: curve,
                  offset: isCovered
                      ? Offset.zero
                      : Offset(reduceMotion ? .08 : 1.08, -.02),
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: curve,
                    opacity: isExiting ? 0 : 1,
                    child: _asset(
                      _rightAsset,
                      cacheWidth: _cacheWidth(context, width * .82),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int? _cacheWidth(BuildContext context, double logicalWidth) {
    final cacheWidth = (logicalWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    return cacheWidth > 0 ? cacheWidth : null;
  }

  Widget _asset(String path, {required int? cacheWidth}) => Image.asset(
    path,
    fit: BoxFit.contain,
    cacheWidth: cacheWidth,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
  );
}
