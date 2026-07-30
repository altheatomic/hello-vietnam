import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/media/media_url_resolver.dart';
import 'package:hellovietnam/features/explore/data/explore_tracking_service.dart';
import 'package:hellovietnam/features/explore/presentation/widgets/explore_floating_back_button.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/item_detail/data/item_detail_repository.dart';
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
    this.itemDetailRepository,
    this.insertedSectionsBuilder,
    this.favoriteType,
    this.favoriteRawId,
    this.favoriteName,
    this.reviewContentType,
    this.showReviews = true,
    this.showWhatToExpect = true,
    this.showTrailingGallery = true,
    this.showFeedbackAction = true,
    this.showRatingBadge = true,
    this.showShareAction,
  }) : assert(
         request != null || detail != null,
         'Either request or detail must be provided.',
       );

  final ItemDetailRequest? request;
  final ItemDetail? detail;
  final ReviewRepository? reviewRepository;
  final ItemDetailRepository? itemDetailRepository;
  final List<Widget> Function(BuildContext context, ItemDetail detail)?
  insertedSectionsBuilder;
  final FavoriteType? favoriteType;
  final String? favoriteRawId;
  final String? favoriteName;
  final ReviewContentType? reviewContentType;
  final bool showReviews;
  final bool showWhatToExpect;

  /// Whether to show the trailing photo gallery cards at the very bottom
  /// of the page (duplicates images already shown in the hero carousel).
  final bool showTrailingGallery;

  /// Whether to show the thumbs-up icon next to the description box.
  final bool showFeedbackAction;

  /// Whether to show the star rating badge over the hero image carousel.
  final bool showRatingBadge;

  /// Overrides whether the share action is shown, independent of
  /// [ItemDetailRequest.trackExploreBehavior]. Null falls back to the
  /// existing `_shouldTrackExploreBehavior` behavior.
  final bool? showShareAction;

  @override
  State<SharedItemDetailPage> createState() => _SharedItemDetailPageState();
}

class _SharedItemDetailPageState extends State<SharedItemDetailPage> {
  late ItemDetail _detail;
  final ExploreTrackingService _exploreTrackingService =
      ExploreTrackingService.instance;
  late bool _isFavorite;
  late final PageController _reviewPageController;
  int _currentPage = 0;
  bool _descExpanded = false;
  FavoriteType? _favoriteType;
  late final String _favoriteRawId;
  late String _favoriteName;
  late double _displayRating;
  bool _isDetailLoading = false;
  Object? _detailError;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail ?? _fallbackDetail(widget.request!);
    _displayRating = _detail.rating;
    _favoriteType =
        widget.favoriteType ??
        widget.request?.favoriteType ??
        _favoriteTypeForDetail(_detail);
    _favoriteRawId = widget.favoriteRawId ?? _detail.id;
    _favoriteName = widget.favoriteName ?? _detail.name;
    _isFavorite = _favoriteType == null
        ? _detail.isFavorite
        : WishlistController.instance.isFavorite(
                type: _favoriteType!,
                rawItemId: _favoriteRawId,
              ) ||
              _detail.isFavorite;
    _reviewPageController = PageController(viewportFraction: 0.9);
    WishlistController.instance.addListener(_syncFavoriteFromController);
    WishlistController.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      _syncFavoriteFromController();
    });
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
    if (widget.detail == null && widget.request != null) {
      _isDetailLoading = true;
      unawaited(_loadLiveDetail());
    }
  }

  ItemDetail _fallbackDetail(ItemDetailRequest request) {
    final List<String> images = <String>[
      ...request.fallbackImages,
      if (request.fallbackImagePath != null) request.fallbackImagePath!.trim(),
    ].where((String image) => image.isNotEmpty).toSet().toList(growable: false);
    return ItemDetail(
      id: request.id,
      name: request.name,
      category: request.category,
      images: images,
      rating: 0,
      reviewCount: 0,
      ratingLabel: '',
      description: '',
      whatToExpect: '',
    );
  }

  Future<void> _loadLiveDetail() async {
    final ItemDetailRequest request = widget.request!;
    try {
      ItemDetail live =
          await (widget.itemDetailRepository ?? ItemDetailRepository.instance)
              .load(request);
      if (live.images.isEmpty && _detail.images.isNotEmpty) {
        live = live.copyWith(images: _detail.images);
      }
      if (!mounted) return;
      setState(() {
        _detail = live;
        _displayRating = live.rating;
        _favoriteType =
            widget.favoriteType ??
            request.favoriteType ??
            _favoriteTypeForDetail(live);
        _favoriteName = widget.favoriteName ?? live.name;
        _detailError = null;
        _isDetailLoading = false;
      });
      _warmImageCache(live);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = error;
        _isDetailLoading = false;
      });
    }
  }

  void _warmImageCache(ItemDetail detail) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final Iterable<String> images = <String>{
        ...detail.effectiveHeroImages,
        ...detail.effectiveGalleryImages,
      };
      for (final String image in images) {
        final String resolved = MediaUrlResolver.resolve(image);
        if (!MediaUrlResolver.isNetwork(resolved)) continue;
        unawaited(precacheImage(NetworkImage(resolved), context));
      }
    });
  }

  @override
  void dispose() {
    WishlistController.instance.removeListener(_syncFavoriteFromController);
    _reviewPageController.dispose();
    super.dispose();
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

  void _syncRatingFromReviews(RatingSummary summary) {
    final double nextRating = summary.reviewCount > 0
        ? summary.averageRating
        : _detail.rating;
    if (!mounted || nextRating == _displayRating) return;
    setState(() => _displayRating = nextRating);
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
          SnackBar(
            content: Text(
              context.l10n.ui('Please sign in to update wishlist.'),
            ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.ui('Update wishlist failed')}: $error'),
        ),
      );
    }
  }

  void _openShareComposer() {
    context.push(
      AppRoutes.forumCreate,
      extra: CreateForumPostRequest(
        sharedExploreItem: SharedExploreItem(
          contentType: _sharedContentType,
          contentId: _detail.id,
          provinceId: _trackingProvinceId,
          title: _detail.name,
          imagePath: _detail.images.isNotEmpty ? _detail.images.first : '',
          category: _detail.category,
          labelOverride: _sharedLabelOverride,
        ),
      ),
    );
  }

  bool get _effectiveShowShareAction =>
      widget.showShareAction ?? _shouldTrackExploreBehavior;

  /// `_favoriteType == FavoriteType.place` identifies the Destinations
  /// (Recommend) place-detail flow, which reuses [DetailCategory.activities]
  /// for `_detail.category` rather than adding a dedicated enum value.
  String get _sharedContentType => _favoriteType == FavoriteType.place
      ? 'place'
      : _sharedContentTypeForCategory(_detail.category);

  String? get _sharedLabelOverride => _favoriteType == FavoriteType.place
      ? context.l10n.ui('Destination')
      : null;

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

  ReviewContentType? get _reviewContentType {
    if (widget.reviewContentType != null) return widget.reviewContentType;
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
                  if (_isDetailLoading) ...<Widget>[
                    const LinearProgressIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.primaryLight,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_detailError != null) ...<Widget>[
                    _DetailLoadError(onRetry: _retryLiveDetail),
                    const SizedBox(height: 12),
                  ],
                  _DetailHeader(title: _detail.name),
                  const SizedBox(height: 20),
                  _HeroImageCarousel(
                    images: _detail.effectiveHeroImages,
                    rating: _displayRating,
                    isFavorite: _isFavorite,
                    showShareAction: _effectiveShowShareAction,
                    showRatingBadge: widget.showRatingBadge,
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
                    showFeedbackAction: widget.showFeedbackAction,
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
                  if (widget.showReviews) ...<Widget>[
                    _SectionTitle(title: context.l10n.ui('Reviews')),
                    const SizedBox(height: 14),
                    if (reviewContentType != null) ...<Widget>[
                      ReviewSection(
                        key: ValueKey<String>(
                          'reviews:${reviewContentType.apiValue}:${_detail.effectiveReviewContentId}',
                        ),
                        contentType: reviewContentType,
                        contentId: _detail.effectiveReviewContentId,
                        itemTitle: _detail.name,
                        repository: widget.reviewRepository,
                        onSummaryChanged: _syncRatingFromReviews,
                      ),
                      const SizedBox(height: 18),
                    ] else ...<Widget>[
                      _ReviewSummary(
                        rating: _detail.rating,
                        reviewCount: _detail.reviewCount,
                      ),
                      const SizedBox(height: 14),
                      _ReviewCarousel(
                        reviews: _detail.reviews,
                        controller: _reviewPageController,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                  if (widget.showWhatToExpect) ...<Widget>[
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
                  ],
                  if (widget.showTrailingGallery)
                    ..._detail.effectiveGalleryImages
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

  Future<void> _retryLiveDetail() async {
    setState(() {
      _detailError = null;
      _isDetailLoading = true;
    });
    await _loadLiveDetail();
  }
}

class _DetailLoadError extends StatelessWidget {
  const _DetailLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.ui('Unable to load item details.'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.ui('Retry')),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: RichText(
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          children: <TextSpan>[
            TextSpan(text: '${context.l10n.ui('Discover')}, '),
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
    required this.showRatingBadge,
    required this.currentPage,
    required this.onPageChanged,
    required this.onFavoriteTap,
    required this.onShareTap,
  });

  final List<String> images;
  final double rating;
  final bool isFavorite;
  final bool showShareAction;
  final bool showRatingBadge;
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
                    key: ValueKey<String>(
                      'detail-image:${displayImages[index]}',
                    ),
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
              if (showRatingBadge)
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
    required this.showFeedbackAction,
    required this.onToggleExpanded,
  });

  final String description;
  final bool isExpanded;
  final bool showFeedbackAction;
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
                          context.l10n.ui(isExpanded ? 'Less' : 'More'),
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
          if (showFeedbackAction) ...<Widget>[
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

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryText = isDark
        ? const Color(0xFFA9BCC7)
        : AppColors.textSecondary;

    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: <Widget>[
        RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              TextSpan(
                text: '/5',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.reviewSummaryLabel(rating),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Text(
                context.l10n.reviewCount(reviewCount),
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCarousel extends StatelessWidget {
  const _ReviewCarousel({required this.reviews, required this.controller});

  final List<ItemReview> reviews;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: controller,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: reviews.length,
            itemBuilder: (BuildContext context, int index) {
              return AnimatedBuilder(
                animation: controller,
                builder: (BuildContext context, Widget? child) {
                  final page = controller.hasClients
                      ? (controller.page ?? controller.initialPage.toDouble())
                      : controller.initialPage.toDouble();
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  final emphasis = (1 - distance).clamp(0.0, 1.0);
                  final scale = 1 - (distance * 0.08);
                  final opacity = 0.82 + (emphasis * 0.18);
                  final translateY = 12 - (emphasis * 12);

                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(0, translateY),
                      child: Opacity(
                        opacity: opacity,
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == reviews.length - 1 ? 0 : 12,
                          ),
                          child: _ReviewCard(
                            review: reviews[index],
                            emphasis: emphasis,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const SizedBox.shrink(),
              );
            },
          ),
        ),
        if (reviews.length > 1) ...<Widget>[
          const SizedBox(height: 14),
          _LiquidPaginationDots(
            controller: controller,
            itemCount: reviews.length,
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, this.emphasis = 1});

  final ItemReview review;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryText = Theme.of(context).colorScheme.onSurface;
    final Color secondaryText = isDark
        ? const Color(0xFFA9BCC7)
        : AppColors.textSecondary;
    final shadowColor = Color.lerp(
      Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
      AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.22),
      emphasis,
    )!;
    final borderColor = Color.lerp(
      Colors.white.withValues(alpha: isDark ? 0.08 : 0.55),
      AppColors.primaryLight.withValues(alpha: isDark ? 0.22 : 0.95),
      emphasis,
    )!;
    final surfaceTop = Color.lerp(
      isDark
          ? const Color(0xFF0B1A22).withValues(alpha: 0.82)
          : Colors.white.withValues(alpha: 0.76),
      isDark
          ? const Color(0xFF122832).withValues(alpha: 0.90)
          : Colors.white.withValues(alpha: 0.92),
      emphasis,
    )!;
    final surfaceBottom = Color.lerp(
      isDark
          ? const Color(0xFF07161D).withValues(alpha: 0.86)
          : AppColors.primaryLight.withValues(alpha: 0.14),
      isDark
          ? const Color(0xFF0B1A22).withValues(alpha: 0.94)
          : AppColors.primaryLight.withValues(alpha: 0.28),
      emphasis,
    )!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12 + (emphasis * 6),
          sigmaY: 12 + (emphasis * 6),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[surfaceTop, surfaceBottom],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.2 + emphasis),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shadowColor,
                blurRadius: 18 + (emphasis * 16),
                offset: Offset(0, 8 + (emphasis * 6)),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -24,
                right: -10,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        isDark
                            ? AppColors.primaryLight.withValues(
                                alpha: 0.08 + (emphasis * 0.04),
                              )
                            : Colors.white.withValues(
                                alpha: 0.4 + (emphasis * 0.18),
                              ),
                        Colors.white.withValues(alpha: isDark ? 0.0 : 0.02),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -34,
                left: -20,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        AppColors.primaryLight.withValues(
                          alpha: 0.20 + (emphasis * 0.12),
                        ),
                        AppColors.primaryLight.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.9),
                              AppColors.primaryLight.withValues(alpha: 0.34),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: 0.10 + (emphasis * 0.10),
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              review.userName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              review.date,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _UserRatingBadge(review: review, emphasis: emphasis),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    review.comment,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: primaryText,
                    ),
                  ),
                  if (review.thumbnails.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: review.thumbnails.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          return _ThumbnailImage(
                            imagePath: review.thumbnails[index],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRatingBadge extends StatelessWidget {
  const _UserRatingBadge({required this.review, this.emphasis = 1});

  final ItemReview review;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = Theme.of(context).colorScheme.onSurface;
    final Color labelColor = isDark
        ? AppColors.primaryLight
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            isDark
                ? const Color(0xFF0B1A22).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.75),
            AppColors.primaryLight.withValues(
              alpha: isDark
                  ? 0.05 + (emphasis * 0.04)
                  : 0.16 + (emphasis * 0.12),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(
            alpha: isDark ? 0.16 + (emphasis * 0.10) : 0.24 + (emphasis * 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            review.ratingLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.star_rounded,
                size: 14,
                color: AppColors.starColor,
              ),
              const SizedBox(width: 4),
              Text(
                review.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiquidPaginationDots extends StatelessWidget {
  const _LiquidPaginationDots({
    required this.controller,
    required this.itemCount,
  });

  final PageController controller;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    const double dotSize = 8;
    const double dotSpacing = 18;

    return SizedBox(
      width: dotSize + ((itemCount - 1) * dotSpacing),
      height: 10,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final page = controller.hasClients
              ? (controller.page ?? controller.initialPage.toDouble())
              : controller.initialPage.toDouble();
          final clampedPage = page.clamp(
            0.0,
            math.max(0, itemCount - 1).toDouble(),
          );
          final stretch = math.sin((clampedPage % 1) * math.pi);
          final blobWidth = dotSize + (dotSpacing * 0.95 * stretch);

          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(
                  itemCount,
                  (int index) => Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(clampedPage * dotSpacing, 0),
                child: Container(
                  width: blobWidth,
                  height: dotSize,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        AppColors.primaryLight,
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
            key: ValueKey<String>('detail-image:$imagePath'),
            imagePath: imagePath,
            borderRadius: 0,
            showOverlay: false,
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        height: 70,
        child: _NetworkOrAssetImage(
          imagePath: imagePath,
          borderRadius: 0,
          showOverlay: false,
        ),
      ),
    );
  }
}

class _NetworkOrAssetImage extends StatelessWidget {
  const _NetworkOrAssetImage({
    super.key,
    required this.imagePath,
    required this.borderRadius,
    required this.showOverlay,
  });

  final String imagePath;
  final double borderRadius;
  final bool showOverlay;

  String get _normalizedImagePath => MediaUrlResolver.resolve(imagePath);

  bool get _isNetworkImage => MediaUrlResolver.isNetwork(_normalizedImagePath);

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
