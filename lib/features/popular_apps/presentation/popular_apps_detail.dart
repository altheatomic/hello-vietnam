import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/popular_apps/data/popular_apps_mock_data.dart';
import 'package:hellovietnam/features/popular_apps/presentation/widgets/popular_apps_video_placeholder.dart';

class PopularAppsDetailPage extends StatelessWidget {
  const PopularAppsDetailPage({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context) {
    final post = popularAppsPosts[appId];

    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Popular Apps')),
        body: const Center(child: Text('App not found')),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            topPadding + 8,
            AppConstants.pagePadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CloseButton(onTap: () => context.pop()),
                  Expanded(
                    child: Center(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {},
                  child: Text(
                    post.ctaLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PopularAppsVideoPlaceholder(
                title: post.heroTitle,
                subtitle: post.heroSubtitle,
              ),
              const SizedBox(height: 18),
              Text(
                post.summaryTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  post.summaryBody,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                post.stepsTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final step in post.steps) ...[
                      Text(
                        step,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 0.83,
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD6DCE5)),
          color: Colors.white.withValues(alpha: 0.72),
        ),
        child: const Icon(Icons.close_rounded, size: 22),
      ),
    );
  }
}
