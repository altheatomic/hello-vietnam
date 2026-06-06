import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/explore/presentation/widgets/explore_floating_back_button.dart';
import 'package:hellovietnam/features/item_detail/data/item_detail_mock_data.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/profile/data/wishlist_controller.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import 'package:hellovietnam/features/report/presentation/report_issue_popup.dart';

class SharedItemDetailPage extends StatefulWidget {
  const SharedItemDetailPage({
    super.key,
    this.request,
    this.detail,
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
  late bool _isFavorite;
  late final PageController _reviewPageController;
  int _currentPage = 0;
  bool _descExpanded = false;
  FavoriteType? _favoriteType;
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
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isFavorite = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update wishlist failed: $error')));
    }
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

  @override
  Widget build(BuildContext context) {
    final insertedSections =
        widget.insertedSectionsBuilder?.call(context, _detail) ??
        const <Widget>[];

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    currentPage: _currentPage,
                    onFavoriteTap: _toggleFavorite,
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
                  _SectionTitle(title: context.l10n.ui('Reviews')),
                  const SizedBox(height: 14),
                  _ReviewSummary(
                    rating: _detail.rating,
                    ratingLabel: _detail.ratingLabel,
                    reviewCount: _detail.reviewCount,
                  ),
                  const SizedBox(height: 14),
                  _ReviewCarousel(
                    reviews: _detail.reviews,
                    controller: _reviewPageController,
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(title: context.l10n.ui('What to expect')),
                  const SizedBox(height: 10),
                  Text(
                    _detail.whatToExpect,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: AppColors.textPrimary,
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
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
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
    required this.currentPage,
    required this.onPageChanged,
    required this.onFavoriteTap,
  });

  final List<String> images;
  final double rating;
  final bool isFavorite;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFavoriteTap;

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
                child: _CircleIconButton(
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  onTap: onFavoriteTap,
                  iconColor: isFavorite
                      ? const Color(0xFFFF5E7A)
                      : Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.28),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  description,
                  maxLines: isExpanded ? null : 3,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onToggleExpanded,
                  child: Text(
                    isExpanded ? 'Less' : 'More',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.thumb_up_alt_outlined,
              size: 20,
              color: AppColors.primary,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.rating,
    required this.ratingLabel,
    required this.reviewCount,
  });

  final double rating;
  final String ratingLabel;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.grey.shade500,
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
                ratingLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$reviewCount reviews',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
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
    final shadowColor = Color.lerp(
      Colors.black.withValues(alpha: 0.04),
      AppColors.primary.withValues(alpha: 0.22),
      emphasis,
    )!;
    final borderColor = Color.lerp(
      Colors.white.withValues(alpha: 0.55),
      AppColors.primaryLight.withValues(alpha: 0.95),
      emphasis,
    )!;
    final surfaceTop = Color.lerp(
      Colors.white.withValues(alpha: 0.76),
      Colors.white.withValues(alpha: 0.92),
      emphasis,
    )!;
    final surfaceBottom = Color.lerp(
      AppColors.primaryLight.withValues(alpha: 0.14),
      AppColors.primaryLight.withValues(alpha: 0.28),
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
                        Colors.white.withValues(alpha: 0.4 + (emphasis * 0.18)),
                        Colors.white.withValues(alpha: 0.02),
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              review.date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
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
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textPrimary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.75),
            AppColors.primaryLight.withValues(alpha: 0.16 + (emphasis * 0.12)),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(
            alpha: 0.24 + (emphasis * 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            review.ratingLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: iconColor, size: 24),
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
    return Tooltip(
      message: context.l10n.ui('Report an Issue'),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Image.asset(
              'assets/images/Auth_Image/problem.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => const Icon(
                    Icons.bug_report_outlined,
                    size: 28,
                    color: Color(0xFF2C2C2C),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
