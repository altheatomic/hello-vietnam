import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// Travel-themed banner using a memory-efficient static image.
class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        gradient: LinearGradient(
          colors: isDark
              ? <Color>[
                  const Color(0xFF102A36),
                  AppColors.primary.withValues(alpha: 0.20),
                ]
              : <Color>[
                  AppColors.primaryLight.withValues(alpha: 0.6),
                  AppColors.accent.withValues(alpha: 0.35),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Image.asset(
      AppConstants.bannerStaticAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 1080,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _fallbackWidget(),
    );
  }

  Widget _fallbackWidget() {
    return Center(
      child: Icon(
        Icons.travel_explore_rounded,
        size: 72,
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
    );
  }
}
