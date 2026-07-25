import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/popular_apps/data/popular_apps_mock_data.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_post.dart';
import 'package:url_launcher/url_launcher.dart';

typedef PopularAppExternalUrlLauncher = Future<bool> Function(Uri uri);

class PopularAppsDetailPage extends StatefulWidget {
  const PopularAppsDetailPage({
    super.key,
    required this.appId,
    this.openExternalUrl,
  });

  final String appId;
  final PopularAppExternalUrlLauncher? openExternalUrl;

  @override
  State<PopularAppsDetailPage> createState() => _PopularAppsDetailPageState();
}

class _PopularAppsDetailPageState extends State<PopularAppsDetailPage> {
  late final PageController _pageController;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PopularAppsPost? post = popularAppsPosts[widget.appId];

    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.ui('Popular Apps'))),
        body: Center(child: Text(context.l10n.ui('App not found'))),
      );
    }

    final double topInset = MediaQuery.of(context).padding.top;
    final List<String> images = <String>[
      post.imageUrl,
      post.logoUrl,
      ...post.galleryImages,
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _DetailBackground()),
          CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _TopBar(
                  topInset: topInset,
                  title: post.title,
                  onBack: () => context.pop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(40, 36, 40, 34),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _DownloadButton(
                        label: post.ctaLabel,
                        onTap: () => _openDownload(post),
                      ),
                      const SizedBox(height: 36),
                      _ImageCarousel(
                        post: post,
                        images: images,
                        controller: _pageController,
                        currentImage: _currentImage,
                        onChanged: (int index) {
                          setState(() => _currentImage = index);
                        },
                        onPrevious: () => _moveImage(images.length, -1),
                        onNext: () => _moveImage(images.length, 1),
                      ),
                      const SizedBox(height: 40),
                      _GlassSection(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              post.summaryTitle,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              post.summaryBody,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      _GlassSection(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              post.stepsTitle,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 24),
                            for (int i = 0; i < post.steps.length; i++)
                              _StepRow(
                                index: i + 1,
                                text: post.steps[i],
                                color: post.accentColor,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _moveImage(int imageCount, int delta) {
    if (imageCount <= 1) return;
    final int next = (_currentImage + delta) % imageCount;
    final int normalized = next < 0 ? imageCount - 1 : next;
    _pageController.animateToPage(
      normalized,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openDownload(PopularAppsPost post) async {
    final Uri uri = Uri.parse(post.downloadUrl);
    try {
      final bool didLaunch = widget.openExternalUrl != null
          ? await widget.openExternalUrl!(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!didLaunch && mounted) _showDownloadError(post);
    } catch (_) {
      if (mounted) _showDownloadError(post);
    }
  }

  void _showDownloadError(PopularAppsPost post) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not open Google Play for ${post.title.replaceFirst(' Guide', '')}.',
          ),
        ),
      );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topInset,
    required this.title,
    required this.onBack,
  });

  final double topInset;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(40, topInset + 18, 40, 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.98 : 0.92,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.open_in_new_rounded, size: 22),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          elevation: 7,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  const _ImageCarousel({
    required this.post,
    required this.images,
    required this.controller,
    required this.currentImage,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final PopularAppsPost post;
  final List<String> images;
  final PageController controller;
  final int currentImage;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: onChanged,
              itemBuilder: (BuildContext context, int index) {
                final String image = images[index];
                if (index == 1) {
                  return _LogoHero(post: post);
                }
                return _NetworkImage(url: image);
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 24,
              right: 18,
              child: Text(
                currentImage == 1 ? post.title : _captionFor(post.appId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CircleButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrevious,
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CircleButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _captionFor(String appId) {
    switch (appId) {
      case 'grab':
      case 'green_sm':
        return 'Book rides in seconds';
      case 'zalo':
        return 'Connect with locals';
      case 'shopeefood':
      case 'foody':
        return 'Discover food around you';
      case 'momo':
        return 'Pay quickly with your phone';
      case 'vinbus':
        return 'Plan public transport routes';
      case 'klook':
        return 'Book travel experiences';
      default:
        return 'Use the app with confidence';
    }
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 30, 32, 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: isDark ? 0.94 : 0.74,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outline
                  : Colors.white.withValues(alpha: 0.72),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.text,
    required this.color,
  });

  final int index;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: index == 5 ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  const _LogoHero({required this.post});

  final PopularAppsPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            post.accentColor.withValues(alpha: 0.92),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox.square(
          dimension: 118,
          child: _AssetLogo(path: post.logoUrl, color: post.accentColor),
        ),
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 44,
          color: Color(0xFF60A5FA),
        ),
      ),
    );
  }
}

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({required this.path, required this.color});

  final String path;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.apps_rounded, color: color),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(
            alpha: isDark ? 0.94 : 0.92,
          ),
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 11,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 25, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class _DetailBackground extends StatelessWidget {
  const _DetailBackground();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const <Color>[
                  Color(0xFF020B10),
                  Color(0xFF0B1A22),
                  Color(0xFF0B2426),
                ]
              : const <Color>[
                  Color(0xFFEFF6FF),
                  Color(0xFFECFEFF),
                  Color(0xFFF0FDFA),
                ],
        ),
      ),
    );
  }
}
