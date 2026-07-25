import 'package:flutter/material.dart';

class ExploreFavoriteIcon extends StatelessWidget {
  const ExploreFavoriteIcon({
    super.key,
    required this.isFavorite,
    this.size = 24,
  });

  static const Color activeColor = Color(0xFFFF5E7A);

  final bool isFavorite;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      isFavorite ? Icons.favorite : Icons.favorite_border,
      color: isFavorite ? activeColor : Colors.white,
      size: size,
    );
  }
}
