import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/reviews/data/review_repository.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';

typedef ReviewSummaryLoader = Future<RatingSummary> Function();
typedef ReviewPageLoader =
    Future<ReviewListPage> Function({
      required int page,
      required int pageSize,
      int? ratingFilter,
    });
typedef MyReviewLoader = Future<MyReviewState> Function();

class ReviewSection extends StatefulWidget {
  const ReviewSection({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.itemTitle,
    this.repository,
    this.initialSummary,
    this.summaryLoader,
    this.loader,
    this.myReviewLoader,
    this.pageSize = 10,
    this.listHeight = 420,
  });

  final ReviewContentType? contentType;
  final String contentId;
  final String itemTitle;
  final ReviewRepository? repository;
  final RatingSummary? initialSummary;
  final ReviewSummaryLoader? summaryLoader;
  final ReviewPageLoader? loader;
  final MyReviewLoader? myReviewLoader;
  final int pageSize;
  final double listHeight;

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
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

  ReviewRepository get _repository =>
      widget.repository ?? ReviewRepository.instance;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
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
    setState(() => _activeRatingFilter = ratingFilter);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadFirstPage();
  }

  String get _ctaLabel =>
      _myReview == null ? 'Write a review' : 'Edit your review';

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
        _SectionHeader(
          summary: summary,
          isLoading: _isLoadingSummary,
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey<String>('review-cta'),
            onPressed: () {},
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(_ctaLabel),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _RatingFilterChip(
              label: 'All',
              selected: _activeRatingFilter == null,
              onSelected: () => unawaited(_applyRatingFilter(null)),
            ),
            for (int star = 5; star >= 1; star -= 1)
              _RatingFilterChip(
                key: ValueKey<String>('review-filter-$star'),
                label: '$star-star',
                selected: _activeRatingFilter == star,
                onSelected: () => unawaited(_applyRatingFilter(star)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: widget.listHeight,
          child: _buildListSurface(theme),
        ),
      ],
    );
  }

  Widget _buildListSurface(ThemeData theme) {
    if (_isLoadingFirstPage && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listError != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Could not load reviews right now.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadFirstPage,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No reviews yet for ${widget.itemTitle}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey<String>('review-list'),
      controller: _scrollController,
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 12),
          child: _ReviewListCard(review: _items[index]),
        );
      },
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
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
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
                  _summaryLabel(effectiveSummary.averageRating),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${effectiveSummary.reviewCount} reviews',
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

  String _summaryLabel(double rating) {
    if (rating >= 4.7) return 'Fantastic';
    if (rating >= 4.3) return 'Great';
    if (rating >= 3.5) return 'Good';
    if (rating > 0) return 'Fair';
    return 'No ratings yet';
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
            '$star star',
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
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
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
        : 'Traveler';
    final String updatedLabel =
        review.updatedAtLabel ?? review.updatedAt ?? review.createdAt ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
