import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

/// Section heading used inside destination detail pages.
///
/// Matches the section title style from Home's RecommendationSection
/// (fontSize: 20, fontWeight: w800, color: AppColors.primary).
class DestSectionTitle extends StatelessWidget {
  const DestSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }
}
