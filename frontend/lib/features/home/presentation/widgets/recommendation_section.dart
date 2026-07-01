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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Background image with gradient opacity ────────
            Positioned.fill(child: _buildBackground(isDark: isDark)),
            if (isDark)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF020B10).withValues(alpha: 0.34),
                        const Color(0xFF020B10).withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                ),
              ),

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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
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
  Widget _buildBackground({required bool isDark}) {
    final double topOpacity = isDark ? 0.34 : 1.0;
    final double bottomOpacity = isDark ? 0.18 : 0.5;

    return Opacity(
      opacity: isDark ? 0.72 : 1,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: topOpacity),
              Colors.white.withValues(alpha: bottomOpacity),
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
                  return _fallbackGradient(isDark: isDark);
                },
                errorBuilder: (_, _, _) => _fallbackGradient(isDark: isDark),
              )
            : Image.asset(
                backgroundImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => _fallbackGradient(isDark: isDark),
              ),
      ),
    );
  }

  Widget _fallbackGradient({required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? <Color>[
                  AppColors.primaryDark.withValues(alpha: 0.16),
                  const Color(0xFF020B10).withValues(alpha: 0.42),
                ]
              : <Color>[
                  AppColors.primaryDark.withValues(alpha: 0.25),
                  AppColors.primaryLight.withValues(alpha: 0.08),
                ],
        ),
      ),
    );
  }
}
