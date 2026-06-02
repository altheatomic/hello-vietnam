import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/popular_apps/data/popular_apps_repository.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_post.dart';
import 'package:hellovietnam/features/popular_apps/presentation/widgets/popular_apps_video_placeholder.dart';

class PopularAppsDetailPage extends StatefulWidget {
  const PopularAppsDetailPage({super.key, required this.appId});

  final String appId;

  @override
  State<PopularAppsDetailPage> createState() => _PopularAppsDetailPageState();
}

class _PopularAppsDetailPageState extends State<PopularAppsDetailPage> {
  final PopularAppsRepository _repo = PopularAppsRepository();

  PopularAppsPost? _post;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final Map<String, dynamic>? row =
          await _repo.fetchDetail(widget.appId);
      if (!mounted) return;
      setState(() {
        _post = row != null ? PopularAppsPost.fromDbRow(row) : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load app details. Tap to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: GestureDetector(
            onTap: _loadPost,
            child: Text(
              _loadError!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final post = _post;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Popular Apps')),
        body: const Center(child: Text('App not found')),
      );
    }

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
                    for (final String step in post.steps) ...<Widget>[
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
