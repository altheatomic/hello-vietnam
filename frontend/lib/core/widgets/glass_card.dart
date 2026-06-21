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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fillColor = isDark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.66)
        : Colors.white.withValues(alpha: opacityValue);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.3);
    final Color shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(radius),
            border: border ?? Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
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
