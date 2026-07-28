import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.blur = 18,
    this.tint,
    this.borderColor,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveTint =
        tint ??
        (isDark
            ? const Color(0xFF102C3B).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.58));
    final Color effectiveBorder =
        borderColor ?? Colors.white.withValues(alpha: isDark ? 0.16 : 0.74);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder),
            boxShadow:
                boxShadow ??
                <BoxShadow>[
                  BoxShadow(
                    color: const Color(
                      0xFF087EAE,
                    ).withValues(alpha: isDark ? 0.22 : 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.42),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
