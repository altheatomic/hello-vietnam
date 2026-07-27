import 'package:flutter/material.dart';

class LacBirdAvatar extends StatelessWidget {
  const LacBirdAvatar({
    super.key,
    this.size = 36,
    this.color,
    this.semanticLabel,
  });

  static const String assetPath = 'assets/images/ai_chat/lac_bird_head.png';

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget image = ClipRect(
      child: Transform.scale(
        scale: 1.45,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: semanticLabel,
        ),
      ),
    );

    return SizedBox.square(
      key: const Key('lac-bird-avatar'),
      dimension: size,
      child: color == null
          ? image
          : ColorFiltered(
              colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
              child: image,
            ),
    );
  }
}
