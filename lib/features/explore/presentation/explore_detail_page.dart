import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../data/explore_detail_data.dart';

class ExploreDetailPage extends StatefulWidget {
  final String itemId;
  final String itemName;

  const ExploreDetailPage({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<ExploreDetailPage> createState() => _ExploreDetailPageState();
}

class _ExploreDetailPageState extends State<ExploreDetailPage> {
  int _currentPage = 0;
  bool _descExpanded = false;
  late final ItemDetail _detail;

  @override
  void initState() {
    super.initState();
    _detail = getItemDetail(widget.itemId, widget.itemName);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final imageCount = _detail.images.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                12, statusBarH + 8, AppConstants.pagePadding, 4,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                        children: [
                          const TextSpan(text: 'Discover, '),
                          TextSpan(
                            text: '${_detail.name}!',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Image carousel ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount: imageCount,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (_, i) => Container(
                          color: Colors.grey.shade300,
                          child: Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                        ),
                      ),
                      if (imageCount > 1)
                        Positioned(
                          bottom: 10, left: 12,
                          child: Row(
                            children: List.generate(imageCount, (i) {
                              return Container(
                                width: i == _currentPage ? 18 : 6, height: 6,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: i == _currentPage ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                      Positioned(
                        bottom: 10, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                _detail.rating.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Description card ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _descExpanded
                          ? _detail.description
                          : '• ${_detail.description}',
                      maxLines: _descExpanded ? null : 3,
                      overflow: _descExpanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _descExpanded = !_descExpanded),
                          child: Text(
                            _descExpanded ? 'Less' : 'More',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.thumb_up, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Reviews section ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      Container(width: 3, height: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Reviews',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Rating summary
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _detail.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('/5', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _detail.ratingLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '${_detail.reviewCount} reviews',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Review cards
                  ..._detail.reviews.map((r) => _ReviewCard(review: r)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── What to expect ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 3, height: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'What to expect',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _detail.whatToExpect,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Gallery ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
              child: Column(
                children: List.generate(
                  _detail.images.length > 3 ? 3 : _detail.images.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Container(
                          color: Colors.grey.shade200,
                          child: Icon(Icons.image_outlined, size: 44, color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─── Review card ─────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ItemReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    Text(
                      review.date,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      review.ratingLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.flag_rounded, color: AppColors.primary, size: 14),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Comment
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          ),

          // Review thumbnails
          if (review.thumbnails.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.thumbnails.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56, height: 56,
                    color: Colors.grey.shade300,
                    child: Icon(Icons.image_outlined, size: 20, color: Colors.grey.shade400),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
