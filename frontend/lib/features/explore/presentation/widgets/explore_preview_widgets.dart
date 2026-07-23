import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/media/media_url_resolver.dart';

class ExplorePreviewImage extends StatelessWidget {
  final String imagePath;
  final double borderRadius;
  final bool darkBottomOverlay;

  const ExplorePreviewImage({
    super.key,
    required this.imagePath,
    this.borderRadius = 20,
    this.darkBottomOverlay = true,
  });

  String get _normalizedImagePath => MediaUrlResolver.resolve(imagePath);

  bool get _isNetworkImage => MediaUrlResolver.isNetwork(_normalizedImagePath);

  bool get _isAssetImage => _normalizedImagePath.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (_isNetworkImage) {
      image = Image.network(
        _normalizedImagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _PreviewFallback(),
      );
    } else if (_isAssetImage) {
      image = Image.asset(
        _normalizedImagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _PreviewFallback(),
      );
    } else {
      image = const _PreviewFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: -18,
            right: -16,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            left: -18,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.transparent,
                    if (darkBottomOverlay)
                      Colors.black.withValues(alpha: 0.42)
                    else
                      Colors.transparent,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExploreLiquidDots extends StatelessWidget {
  final PageController controller;
  final int itemCount;
  final Color activeColor;
  final Color inactiveColor;

  const ExploreLiquidDots({
    super.key,
    required this.controller,
    required this.itemCount,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x66FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 1) return const SizedBox.shrink();

    const double dotSize = 7;
    const double dotSpacing = 17;

    return SizedBox(
      width: dotSize + ((itemCount - 1) * dotSpacing),
      height: 10,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final page = controller.hasClients
              ? (controller.page ?? controller.initialPage.toDouble())
              : controller.initialPage.toDouble();
          final clampedPage = page.clamp(
            0.0,
            math.max(0, itemCount - 1).toDouble(),
          );
          final stretch = math.sin((clampedPage % 1) * math.pi);
          final blobWidth = dotSize + (dotSpacing * 0.95 * stretch);

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  itemCount,
                  (index) => Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: inactiveColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(clampedPage * dotSpacing, 0),
                child: Container(
                  width: blobWidth,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF84D5F7), Color(0xFF3AA6DE), Color(0xFF1F628C)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_back_outlined,
          size: 36,
          color: Colors.white.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}
