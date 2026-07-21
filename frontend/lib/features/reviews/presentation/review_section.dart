import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/reviews/data/review_repository.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';
import 'package:hellovietnam/features/reviews/presentation/review_composer_sheet.dart';

typedef ReviewSummaryLoader = Future<RatingSummary> Function();
typedef ReviewPageLoader =
    Future<ReviewListPage> Function({
      required int page,
      required int pageSize,
      int? ratingFilter,
    });
typedef MyReviewLoader = Future<MyReviewState> Function();
typedef ReviewUpsertCallback =
    Future<UpsertReviewResult> Function({
      required int rating,
      required String comment,
    });

class ReviewSection extends StatefulWidget {
  const ReviewSection({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.itemTitle,
    this.repository,
    this.summaryLoader,
    this.loader,
    this.myReviewLoader,
    this.upsertReview,
    this.pageSize = 10,
    this.listHeight = 420,
    this.onSummaryChanged,
  });

  final ReviewContentType? contentType;
  final String contentId;
  final String itemTitle;
  final ReviewRepository? repository;
  final ReviewSummaryLoader? summaryLoader;
  final ReviewPageLoader? loader;
  final MyReviewLoader? myReviewLoader;
  final ReviewUpsertCallback? upsertReview;
  final int pageSize;
  final double listHeight;
  final ValueChanged<RatingSummary>? onSummaryChanged;

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  static const int _previewCount = 2;

  late final ScrollController _scrollController;
  RatingSummary? _summary;
  ReviewEntry? _myReview;
  final List<ReviewEntry> _items = <ReviewEntry>[];
  bool _isLoadingSummary = false;
  bool _isLoadingFirstPage = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  int? _activeRatingFilter;
  Object? _listError;
  bool _showAll = false;

  ReviewRepository get _repository =>
      widget.repository ?? ReviewRepository.instance;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    unawaited(_loadInitialData());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>(<Future<void>>[
      _loadSummary(),
      _loadMyReview(),
      _loadFirstPage(),
    ]);
  }

  Future<void> _loadSummary() async {
    final ReviewSummaryLoader? summaryLoader = widget.summaryLoader;
    if (widget.contentType == null && summaryLoader == null) {
      return;
    }

    setState(() => _isLoadingSummary = true);
    try {
      final RatingSummary summary =
          await (summaryLoader?.call() ??
              _repository.loadSummary(
                contentType: widget.contentType!,
                contentId: widget.contentId,
              ));
      if (!mounted) return;
      setState(() => _summary = summary);
      widget.onSummaryChanged?.call(summary);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  Future<void> _loadMyReview() async {
    final MyReviewLoader? myReviewLoader = widget.myReviewLoader;
    if (widget.contentType == null && myReviewLoader == null) {
      return;
    }

    try {
      final MyReviewState state =
          await (myReviewLoader?.call() ??
              _repository.loadMyReview(
                contentType: widget.contentType!,
                contentId: widget.contentId,
              ));
      if (!mounted) return;
      setState(() => _myReview = state.review);
    } catch (_) {
      if (!mounted) return;
      setState(() => _myReview = null);
    }
  }

  Future<void> _loadFirstPage() async {
    if (_isLoadingFirstPage) return;
    setState(() {
      _isLoadingFirstPage = true;
      _listError = null;
      _currentPage = 0;
      _hasMore = false;
      _showAll = false;
      _items.clear();
    });

    try {
      await _appendPage(1, reset: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _listError = error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingFirstPage = false);
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || _isLoadingFirstPage || !_hasMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      await _appendPage(_currentPage + 1);
    } catch (error) {
      if (!mounted) return;
      setState(() => _listError = error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _appendPage(int page, {bool reset = false}) async {
    final ReviewPageLoader? loader = widget.loader;
    if (widget.contentType == null && loader == null) {
      return;
    }

    final ReviewListPage response =
        await (loader?.call(
              page: page,
              pageSize: widget.pageSize,
              ratingFilter: _activeRatingFilter,
            ) ??
            _repository.loadReviews(
              contentType: widget.contentType!,
              contentId: widget.contentId,
              page: page,
              pageSize: widget.pageSize,
              ratingFilter: _activeRatingFilter,
            ));

    if (!mounted) return;
    setState(() {
      _currentPage = response.page;
      _hasMore = response.hasMore;
      _listError = null;
      if (reset) {
        _items
          ..clear()
          ..addAll(response.items);
      } else {
        _items.addAll(response.items);
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 180) {
      return;
    }
    unawaited(_loadNextPage());
  }

  Future<void> _applyRatingFilter(int? ratingFilter) async {
    if (_activeRatingFilter == ratingFilter) return;
    setState(() {
      _activeRatingFilter = ratingFilter;
      _showAll = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadFirstPage();
  }

  Future<UpsertReviewResult> _submitReview({
    required int rating,
    required String comment,
  }) {
    final ReviewUpsertCallback? upsertReview = widget.upsertReview;
    if (upsertReview != null) {
      return upsertReview(rating: rating, comment: comment);
    }
    return _repository.upsertReview(
      contentType: widget.contentType!,
      contentId: widget.contentId,
      rating: rating,
      comment: comment,
    );
  }

  Future<void> _openComposer() async {
    if (widget.contentType == null) {
      return;
    }

    final UpsertReviewResult? result =
        await showModalBottomSheet<UpsertReviewResult>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return ReviewComposerSheet(
              itemTitle: widget.itemTitle,
              initialReview: _myReview,
              submitLabel: _myReview == null
                  ? context.l10n.ui('Publish review')
                  : context.l10n.ui('Update review'),
              onSubmit: ({required int rating, required String comment}) =>
                  _submitReview(rating: rating, comment: comment),
            );
          },
        );

    if (!mounted || result == null) {
      return;
    }

    final int? previousFilter = _activeRatingFilter;
    setState(() {
      _summary = result.summary;
      _myReview = result.review;
      _activeRatingFilter = null;
      _showAll = false;
    });
    widget.onSummaryChanged?.call(result.summary);

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if (previousFilter == null) {
      setState(() {
        _items
          ..removeWhere((ReviewEntry item) => item.id == result.review.id)
          ..insert(0, result.review);
      });
    }

    await _loadFirstPage();
  }

  String _ctaLabel(BuildContext context) => _myReview == null
      ? context.l10n.ui('Write a review')
      : context.l10n.ui('Edit your review');

  @override
  Widget build(BuildContext context) {
    if (widget.contentType == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final RatingSummary? summary = _summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(summary: summary, isLoading: _isLoadingSummary),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: _LiquidReviewButton(
            onPressed: _openComposer,
            label: _ctaLabel(context),
          ),
        ),
        const SizedBox(height: 12),
        const _ReviewDivider(),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _RatingFilterChip(
                  label: context.l10n.ui('All'),
                  selected: _activeRatingFilter == null,
                  onSelected: () => unawaited(_applyRatingFilter(null)),
                );
              }
              final int star = 6 - index;
              return _RatingFilterChip(
                key: ValueKey<String>('review-filter-$star'),
                label: context.l10n.reviewRatingFilterLabel(star),
                selected: _activeRatingFilter == star,
                onSelected: () => unawaited(_applyRatingFilter(star)),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildListSurface(theme),
        const SizedBox(height: 10),
        const _ReviewDivider(),
      ],
    );
  }

  Widget _buildListSurface(ThemeData theme) {
    if (_isLoadingFirstPage && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_listError != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(context.l10n.ui('Could not load reviews right now.')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadFirstPage,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            context.l10n.noReviewsYetFor(widget.itemTitle),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final bool canShowAll = _items.length > _previewCount || _hasMore;
    if (!_showAll) {
      final List<ReviewEntry> previewItems = _items
          .take(_previewCount)
          .toList(growable: false);
      return Column(
        key: const ValueKey<String>('review-list-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < previewItems.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == previewItems.length - 1 ? 0 : 12,
              ),
              child: _ReviewListCard(review: previewItems[index]),
            ),
          if (canShowAll) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey<String>('review-see-all'),
                onPressed: () => setState(() => _showAll = true),
                child: Text(context.l10n.ui('See all')),
              ),
            ),
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.listHeight),
      child: ListView.builder(
        key: const ValueKey<String>('review-list'),
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _items.length - 1 ? 0 : 12,
            ),
            child: _ReviewListCard(review: _items[index]),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.summary, required this.isLoading});

  final RatingSummary? summary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RatingSummary effectiveSummary =
        summary ??
        const RatingSummary(
          averageRating: 0,
          reviewCount: 0,
          rating1Count: 0,
          rating2Count: 0,
          rating3Count: 0,
          rating4Count: 0,
          rating5Count: 0,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                effectiveSummary.averageRating.toStringAsFixed(1),
                key: const ValueKey<String>('review-summary-average'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  context.l10n.reviewSummaryLabel(
                    effectiveSummary.averageRating,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.reviewCount(effectiveSummary.reviewCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (int star = 5; star >= 1; star -= 1)
            Padding(
              padding: EdgeInsets.only(bottom: star == 1 ? 0 : 8),
              child: _RatingBreakdownRow(
                star: star,
                count: effectiveSummary.countForStar(star),
                totalCount: effectiveSummary.totalStarCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingBreakdownRow extends StatelessWidget {
  const _RatingBreakdownRow({
    required this.star,
    required this.count,
    required this.totalCount,
  });

  final int star;
  final int count;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final double progress = totalCount == 0 ? 0 : count / totalCount;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 48,
          child: Text(
            context.l10n.reviewBreakdownStarLabel(star),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _RatingFilterChip extends StatelessWidget {
  const _RatingFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.28),
      backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.92),
      checkmarkColor: AppColors.textPrimary,
      side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.48)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
    );
  }
}

class _ReviewDivider extends StatelessWidget {
  const _ReviewDivider();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color lineColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.primaryDark.withValues(alpha: 0.16);

    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            lineColor.withValues(alpha: 0),
            lineColor,
            lineColor.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _LiquidReviewButton extends StatefulWidget {
  const _LiquidReviewButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_LiquidReviewButton> createState() => _LiquidReviewButtonState();
}

class _LiquidReviewButtonState extends State<_LiquidReviewButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground = isDark ? Colors.white : AppColors.textOnPrimary;
    final Color borderColor = Colors.white.withValues(
      alpha: isDark ? 0.22 : 0.42,
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryDark.withValues(
                  alpha: isDark ? 0.28 : 0.24,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.32),
                blurRadius: 8,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey<String>('review-cta'),
                  onTap: widget.onPressed,
                  onHighlightChanged: _setPressed,
                  borderRadius: BorderRadius.circular(999),
                  splashColor: Colors.white.withValues(alpha: 0.16),
                  highlightColor: Colors.white.withValues(alpha: 0.08),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.accent.withValues(
                            alpha: isDark ? 0.84 : 0.92,
                          ),
                          AppColors.primary.withValues(
                            alpha: isDark ? 0.82 : 0.95,
                          ),
                          AppColors.primaryApple.withValues(
                            alpha: isDark ? 0.72 : 0.78,
                          ),
                        ],
                      ),
                      border: Border.all(color: borderColor),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          top: -14,
                          bottom: 20,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.26 : 0.34,
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.rate_review_outlined,
                              color: foreground,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({required this.review});

  final ReviewEntry review;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String reviewer = review.userName?.trim().isNotEmpty == true
        ? review.userName!
        : context.l10n.ui('Traveler');
    final String updatedLabel = _formatReviewTimestamp(context, review);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reviewer,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (updatedLabel.isNotEmpty)
                      Text(
                        updatedLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.starColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.rating.toString(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

String _formatReviewTimestamp(BuildContext context, ReviewEntry review) {
  final String raw =
      (review.updatedAtLabel ?? review.updatedAt ?? review.createdAt ?? '')
          .trim();
  if (raw.isEmpty) return '';

  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final DateTime local = parsed.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  final bool hasTime = raw.length > 10;

  if (context.l10n.appLanguage == AppLanguage.vietnamese) {
    final String date = '$day/$month/${local.year}';
    return hasTime ? '$date • $hour:$minute' : date;
  }

  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final String date = '${months[local.month - 1]} ${local.day}, ${local.year}';
  return hasTime ? '$date • $hour:$minute' : date;
}
