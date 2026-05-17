import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// A reusable glassmorphism card inspired by iOS 26 Liquid Glass.
///
/// Features:
/// - Frosted-glass backdrop blur
/// - Semi-transparent white fill
/// - Subtle luminous border
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur,
    this.opacity,
    this.padding,
    this.border,
  });

  final Widget child;
  final double? borderRadius;
  final double? blur;
  final double? opacity;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppConstants.cardRadius;
    final blurValue = blur ?? AppConstants.glassBlur;
    final opacityValue = opacity ?? AppConstants.glassOpacity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacityValue),
            borderRadius: BorderRadius.circular(radius),
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.0,
                ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
