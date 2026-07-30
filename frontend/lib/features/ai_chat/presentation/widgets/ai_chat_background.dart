import 'package:flutter/material.dart';

class AiChatBackground extends StatelessWidget {
  const AiChatBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: const Key('ai-chat-liquid-background'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[
                  Color(0xFF020B12),
                  Color(0xFF082536),
                  Color(0xFF061B24),
                ]
              : const <Color>[
                  Color(0xFFF4FCFF),
                  Color(0xFFDFF5FF),
                  Color(0xFFEAFBF8),
                ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            right: -65,
            child: _GlowOrb(
              size: 230,
              color: const Color(
                0xFF35C8F4,
              ).withValues(alpha: isDark ? 0.18 : 0.24),
            ),
          ),
          Positioned(
            bottom: 70,
            left: -90,
            child: _GlowOrb(
              size: 250,
              color: const Color(
                0xFF35D9C5,
              ).withValues(alpha: isDark ? 0.12 : 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
