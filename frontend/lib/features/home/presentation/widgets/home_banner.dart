import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// Travel-themed banner that displays a looping GIF from local assets.
class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.6),
            AppColors.accent.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Image.asset(
      AppConstants.bannerGifAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
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
