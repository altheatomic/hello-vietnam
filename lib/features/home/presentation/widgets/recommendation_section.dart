import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// A horizontal-scroll section with a background image whose opacity
/// fades linearly from 100 % at the top to 50 % at the bottom.
///
/// Used for both "Best Destination" and "Best Dishes" sections.
///
/// Supports both **network URLs** and **asset paths** for [backgroundImage].
/// If the path starts with `http` it loads from network, otherwise from assets.
class RecommendationSection extends StatelessWidget {
  const RecommendationSection({
    super.key,
    required this.title,
    required this.backgroundImage,
    required this.children,
    this.height = 310,
  });

  final String title;
  final String backgroundImage;
  final List<Widget> children;
  final double height;

  bool get _isNetworkImage => backgroundImage.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Background image with gradient opacity ────────
            Positioned.fill(child: _buildBackground()),

            // ── Content ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.pagePadding,
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horizontal card list
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.pagePadding,
                      ),
                      itemCount: children.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => children[i],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the background image with a linear gradient mask:
  /// 100 % opaque at the top → 50 % opaque at the bottom.
  Widget _buildBackground() {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white, // 100 %
            Colors.white.withValues(alpha: 0.5), // 50 %
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: _isNetworkImage
          ? Image.network(
              backgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _fallbackGradient();
              },
              errorBuilder: (_, _, _) => _fallbackGradient(),
            )
          : Image.asset(
              backgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => _fallbackGradient(),
            ),
    );
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.25),
            AppColors.primaryLight.withValues(alpha: 0.08),
          ],
        ),
      ),
    );
  }
}
