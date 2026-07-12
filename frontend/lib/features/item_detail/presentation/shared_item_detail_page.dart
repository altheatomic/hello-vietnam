import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/explore/data/explore_tracking_service.dart';
import 'package:hellovietnam/features/explore/presentation/widgets/explore_floating_back_button.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/item_detail/data/item_detail_mock_data.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/profile/data/wishlist_controller.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import 'package:hellovietnam/features/report/presentation/report_issue_popup.dart';
import 'package:hellovietnam/features/reviews/data/review_repository.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';
import 'package:hellovietnam/features/reviews/presentation/review_section.dart';

class SharedItemDetailPage extends StatefulWidget {
  const SharedItemDetailPage({
    super.key,
    this.request,
    this.detail,
    this.reviewRepository,
    this.insertedSectionsBuilder,
    this.favoriteType,
    this.favoriteRawId,
    this.favoriteName,
  }) : assert(
         request != null || detail != null,
         'Either request or detail must be provided.',
       );

  final ItemDetailRequest? request;
  final ItemDetail? detail;
  final ReviewRepository? reviewRepository;
  final List<Widget> Function(BuildContext context, ItemDetail detail)?
  insertedSectionsBuilder;
  final FavoriteType? favoriteType;
  final String? favoriteRawId;
  final String? favoriteName;

  @override
  State<SharedItemDetailPage> createState() => _SharedItemDetailPageState();
}

class _SharedItemDetailPageState extends State<SharedItemDetailPage> {
  late final ItemDetail _detail;
  final ExploreTrackingService _exploreTrackingService =
      ExploreTrackingService.instance;
  late bool _isFavorite;
  int _currentPage = 0;
  bool _descExpanded = false;
  FavoriteType? _favoriteType;
  bool _wishlistListenerBound = false;
  late final String _favoriteRawId;
  late final String _favoriteName;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail ?? resolveItemDetail(widget.request!);
    _favoriteType =
        widget.favoriteType ??
        widget.request?.favoriteType ??
        _favoriteTypeForDetail(_detail);
    _favoriteRawId = widget.favoriteRawId ?? _detail.id;
    _favoriteName = widget.favoriteName ?? _detail.name;
    _isFavorite = _favoriteType == null
        ? _detail.isFavorite
        : _safeWishlistFavoriteLookup() || _detail.isFavorite;
    _bindWishlistController();
    if (_shouldTrackExploreBehavior) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          _exploreTrackingService.trackViewDetail(
            category: _detail.category,
            contentId: _detail.id,
            provinceId: _trackingProvinceId,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    if (_wishlistListenerBound) {
      WishlistController.instance.removeListener(_syncFavoriteFromController);
    }
    super.dispose();
  }

  void _bindWishlistController() {
    if (_favoriteType == null) {
      return;
    }
    try {
      WishlistController.instance.addListener(_syncFavoriteFromController);
      _wishlistListenerBound = true;
      WishlistController.instance.ensureLoaded().then((_) {
        if (!mounted) return;
        _syncFavoriteFromController();
      });
    } catch (_) {
      _wishlistListenerBound = false;
    }
  }

  bool _safeWishlistFavoriteLookup() {
    final FavoriteType? type = _favoriteType;
    if (type == null) {
      return false;
    }
    try {
      return WishlistController.instance.isFavorite(
        type: type,
        rawItemId: _favoriteRawId,
      );
    } catch (_) {
      return false;
    }
  }

  void _syncFavoriteFromController() {
    final FavoriteType? type = _favoriteType;
    if (type == null) return;
    final bool next = WishlistController.instance.isFavorite(
      type: type,
      rawItemId: _favoriteRawId,
    );
    if (next == _isFavorite) return;
    setState(() => _isFavorite = next);
  }

  Future<void> _toggleFavorite() async {
    final FavoriteType? type = _favoriteType;
    if (type == null) {
      setState(() => _isFavorite = !_isFavorite);
      return;
    }

    final bool previous = _isFavorite;
    setState(() => _isFavorite = !previous);
    try {
      final bool? next = await WishlistController.instance.toggleFavorite(
        type: type,
        rawItemId: _favoriteRawId,
        fallbackName: _favoriteName,
      );
      if (!mounted) return;
      if (next == null) {
        setState(() => _isFavorite = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to update wishlist.')),
        );
      } else {
        setState(() => _isFavorite = next);
        if (_shouldTrackExploreBehavior) {
          unawaited(
            _exploreTrackingService.trackFavoriteChanged(
              category: _detail.category,
              contentId: _detail.id,
              provinceId: _trackingProvinceId,
              isFavorite: next,
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isFavorite = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update wishlist failed: $error')));
    }
  }

  void _openShareComposer() {
    context.push(
      AppRoutes.forumCreate,
      extra: CreateForumPostRequest(
        sharedExploreItem: SharedExploreItem(
          contentType: _sharedContentTypeForCategory(_detail.category),
          contentId: _detail.id,
          provinceId: _trackingProvinceId,
          title: _detail.name,
          imagePath: _detail.images.isNotEmpty ? _detail.images.first : '',
          category: _detail.category,
        ),
      ),
    );
  }

  FavoriteType? _favoriteTypeForDetail(ItemDetail detail) {
    switch (detail.category) {
      case DetailCategory.activities:
        return FavoriteType.activity;
      case DetailCategory.culture:
        return FavoriteType.culture;
      case DetailCategory.food:
        return FavoriteType.food;
      case DetailCategory.localProducts:
        return FavoriteType.localProduct;
    }
  }

  bool get _shouldTrackExploreBehavior =>
      widget.request?.trackExploreBehavior == true;

  String? get _trackingProvinceId => widget.request?.exploreProvinceId;

  String _sharedContentTypeForCategory(DetailCategory category) {
    switch (category) {
      case DetailCategory.activities:
        return 'activity';
      case DetailCategory.culture:
        return 'culture';
      case DetailCategory.food:
        return 'food';
      case DetailCategory.localProducts:
        return 'local_product';
    }
  }

  RatingSummary _initialReviewSummary(ItemDetail detail) {
    final int reviewCount = detail.reviewCount;
    if (reviewCount == 0) {
      return const RatingSummary(
        averageRating: 0,
        reviewCount: 0,
        rating1Count: 0,
        rating2Count: 0,
        rating3Count: 0,
        rating4Count: 0,
        rating5Count: 0,
      );
    }

    final int lowerStar = detail.rating.floor().clamp(1, 5);
    final int upperStar = detail.rating.ceil().clamp(1, 5);
    final int upperCount = lowerStar == upperStar
        ? reviewCount
        : ((detail.rating - lowerStar) * reviewCount).round().clamp(0, reviewCount);
    final int lowerCount = reviewCount - upperCount;

    return RatingSummary(
      averageRating: detail.rating,
      reviewCount: reviewCount,
      rating1Count: lowerStar == 1 ? lowerCount : upperStar == 1 ? upperCount : 0,
      rating2Count: lowerStar == 2 ? lowerCount : upperStar == 2 ? upperCount : 0,
      rating3Count: lowerStar == 3 ? lowerCount : upperStar == 3 ? upperCount : 0,
      rating4Count: lowerStar == 4 ? lowerCount : upperStar == 4 ? upperCount : 0,
      rating5Count: lowerStar == 5 ? lowerCount : upperStar == 5 ? upperCount : 0,
    );
  }

  ReviewContentType? get _reviewContentType {
    if (!_detail.hasReviewTarget) {
      return null;
    }
    return reviewContentTypeForDetailCategory(_detail.category);
  }

  @override
  Widget build(BuildContext context) {
    final insertedSections =
        widget.insertedSectionsBuilder?.call(context, _detail) ??
        const <Widget>[];
    final ReviewContentType? reviewContentType = _reviewContentType;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                56,
                AppConstants.pagePadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DetailHeader(title: _detail.name),
                  const SizedBox(height: 20),
                  _HeroImageCarousel(
                    images: _detail.images,
                    rating: _detail.rating,
                    isFavorite: _isFavorite,
                    showShareAction: _shouldTrackExploreBehavior,
                    currentPage: _currentPage,
                    onFavoriteTap: _toggleFavorite,
                    onShareTap: _openShareComposer,
                    onPageChanged: (int index) {
                      setState(() => _currentPage = index);
                    },
                  ),
                  const SizedBox(height: 18),
                  _QuickInfoCard(
                    description: _detail.description,
                    isExpanded: _descExpanded,
                    onToggleExpanded: () {
                      setState(() => _descExpanded = !_descExpanded);
                    },
                  ),
                  if (insertedSections.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    ...insertedSections,
                    const SizedBox(height: 28),
                  ] else
                    const SizedBox(height: 28),
                  if (reviewContentType != null) ...<Widget>[
                    _SectionTitle(title: context.l10n.ui('Reviews')),
                    const SizedBox(height: 14),
                    ReviewSection(
                      contentType: reviewContentType,
                      contentId: _detail.effectiveReviewContentId,
                      itemTitle: _detail.name,
                      repository: widget.reviewRepository,
                      initialSummary: _initialReviewSummary(_detail),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _SectionTitle(title: context.l10n.ui('What to expect')),
                  const SizedBox(height: 10),
                  Text(
                    _detail.whatToExpect,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 18),
                  ..._detail.images
                      .take(4)
                      .map(
                        (String image) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GalleryImageCard(imagePath: image),
                        ),
                      ),
                ],
              ),
            ),
          ),
          ExploreFloatingBackButton(onTap: () => context.pop()),
          Positioned(
            top: 6,
            right: AppConstants.pagePadding,
            child: SafeArea(
              child: _ReportAssetIconButton(
                onTap: () => showReportIssueFlow(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          children: <TextSpan>[
            const TextSpan(text: 'Discover, '),
            TextSpan(
              text: '$title!',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImageCarousel extends StatelessWidget {
  const _HeroImageCarousel({
    required this.images,
    required this.rating,
    required this.isFavorite,
    required this.showShareAction,
    required this.currentPage,
    required this.onPageChanged,
    required this.onFavoriteTap,
    required this.onShareTap,
  });

  final List<String> images;
  final double rating;
  final bool isFavorite;
  final bool showShareAction;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFavoriteTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    final displayImages = images.isEmpty ? const <String>[''] : images;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 11,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PageView.builder(
                itemCount: displayImages.length,
                onPageChanged: onPageChanged,
                itemBuilder: (BuildContext context, int index) {
                  return _NetworkOrAssetImage(
                    imagePath: displayImages[index],
                    borderRadius: 0,
                    showOverlay: true,
                  );
                },
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Column(
                  children: <Widget>[
                    _CircleIconButton(
                      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                      onTap: onFavoriteTap,
                      iconColor: isFavorite
                          ? const Color(0xFFFF5E7A)
                          : Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.28),
                    ),
                    if (showShareAction) ...<Widget>[
                      const SizedBox(height: 10),
                      _CircleIconButton(
                        icon: Icons.share_outlined,
                        onTap: onShareTap,
                        iconColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.28),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: _PaginationDots(
                  itemCount: displayImages.length,
                  currentIndex: currentPage,
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: _RatingBadge(rating: rating),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  const _QuickInfoCard({
    required this.description,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final String description;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final TextStyle descriptionStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: theme.colorScheme.onSurface,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.88)
            : AppColors.primaryLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final TextPainter textPainter = TextPainter(
                  text: TextSpan(text: description, style: descriptionStyle),
                  maxLines: 3,
                  textDirection: Directionality.of(context),
                )..layout(maxWidth: constraints.maxWidth);
                final bool canExpand = textPainter.didExceedMaxLines;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      description,
                      maxLines: isExpanded ? null : 3,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                      style: descriptionStyle,
                    ),
                    if (canExpand) ...<Widget>[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onToggleExpanded,
                        child: Text(
                          isExpanded ? 'Less' : 'More',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF102832).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.82),
              border: isDark
                  ? Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.14),
                    )
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.thumb_up_alt_outlined,
              size: 20,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _GalleryImageCard extends StatelessWidget {
  const _GalleryImageCard({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: _NetworkOrAssetImage(
            imagePath: imagePath,
            borderRadius: 0,
            showOverlay: false,
          ),
        ),
      ),
    );
  }
}

class _NetworkOrAssetImage extends StatelessWidget {
  const _NetworkOrAssetImage({
    required this.imagePath,
    required this.borderRadius,
    required this.showOverlay,
  });

  final String imagePath;
  final double borderRadius;
  final bool showOverlay;

  String get _normalizedImagePath {
    String value = imagePath.trim();
    for (int i = 0; i < 2; i++) {
      if (value.contains('%')) {
        value = Uri.decodeFull(value);
      }
    }
    return value;
  }

  bool get _isNetworkImage =>
      _normalizedImagePath.startsWith('http://') ||
      _normalizedImagePath.startsWith('https://');

  bool get _isAssetImage => _normalizedImagePath.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_isNetworkImage) {
      child = Image.network(
        _normalizedImagePath,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _ImageFallback(showOverlay: showOverlay),
      );
    } else if (_isAssetImage) {
      child = Image.asset(
        _normalizedImagePath,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _ImageFallback(showOverlay: showOverlay),
      );
    } else {
      child = _ImageFallback(showOverlay: showOverlay);
    }

    if (borderRadius == 0) {
      return child;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.showOverlay});

  final bool showOverlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF82D0F4),
            const Color(0xFF2B7DB8),
            if (showOverlay) const Color(0xFF1F4F78),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -26,
            left: -18,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.photo_camera_back_outlined,
              size: 42,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationDots extends StatelessWidget {
  const _PaginationDots({required this.itemCount, required this.currentIndex});

  final int itemCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        itemCount,
        (int index) => AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          width: index == currentIndex ? 18 : 7,
          height: 7,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: index == currentIndex
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, color: AppColors.starColor, size: 16),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.primary,
    this.backgroundColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark && backgroundColor == Colors.white
          ? Colors.white.withValues(alpha: 0.08)
          : backgroundColor,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: isDark && iconColor == AppColors.primary
                ? AppColors.primaryLight
                : iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ReportAssetIconButton extends StatelessWidget {
  const _ReportAssetIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = isDark
        ? const Color(0xFF87CEEB)
        : const Color(0xFF2C2C2C);

    return Tooltip(
      message: context.l10n.ui('Report an Issue'),
      child: Material(
        color: isDark
            ? const Color(0xFF0B1A22).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.88),
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF87CEEB).withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                child: Image.asset(
                  'assets/images/Auth_Image/problem.png',
                  width: 25,
                  height: 25,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) => Icon(
                        Icons.bug_report_outlined,
                        size: 25,
                        color: iconColor,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
