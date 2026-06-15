import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import 'package:hellovietnam/features/profile/data/wishlist_controller.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import '../../data/recommend_mock_data.dart';
import '../../domain/recommend_destination.dart';

class RecommendWhenResultsPage extends StatelessWidget {
  const RecommendWhenResultsPage({super.key, required this.dateRange});

  final DateTimeRange dateRange;

  List<RecommendDestination> get _filtered {
    final int month = dateRange.start.month;
    return mockRecommendDestinations.where((RecommendDestination d) {
      return d.bestMonths.isEmpty || d.bestMonths.contains(month);
    }).toList();
  }

  String _monthShort(int month) {
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
    return months[month - 1];
  }

  String get _rangeLabel {
    return '${_monthShort(dateRange.start.month)} ${dateRange.start.day} - ${_monthShort(dateRange.end.month)} ${dateRange.end.day}';
  }

  String get _durationLabel {
    final int days = dateRange.duration.inDays + 1;
    return '$days ${days == 1 ? 'day' : 'days'} trip';
  }

  @override
  Widget build(BuildContext context) {
    final List<RecommendDestination> results = _filtered;
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFFE9FBFF),
              const Color(0xFFF5FDFF),
              Colors.white.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: results.isEmpty
            ? SafeArea(
                child: const EmptyState(
                  icon: Icons.calendar_today_rounded,
                  message:
                      'No destinations found for your travel dates.\nTry a different period.',
                ),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(6, topInset + 6, 6, 0),
                      child: Row(
                        children: <Widget>[
                          _TopCircleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const Expanded(
                            child: Text(
                              'Recommendation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2EA7F8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 34),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DateCardHeaderDelegate(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                        child: _EditableDateCard(
                          rangeLabel: _rangeLabel,
                          durationLabel: _durationLabel,
                          onTap: () =>
                              context.push(AppRoutes.recommendWhenCalendar),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 20),
                    sliver: SliverList.separated(
                      itemCount: results.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _SuggestionCard(destination: results[index]);
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 13, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

class _EditableDateCard extends StatelessWidget {
  const _EditableDateCard({
    required this.rangeLabel,
    required this.durationLabel,
    required this.onTap,
  });

  final String rangeLabel;
  final String durationLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCDEDF9)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: Color(0xFF2EA7F8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      durationLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF2EA7F8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateCardHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateCardHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 86;

  @override
  double get maxExtent => 86;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFEAFBFF).withValues(alpha: 0.98),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _DateCardHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({required this.destination});

  final RecommendDestination destination;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  final WishlistController _wishlistController = WishlistController.instance;

  @override
  void initState() {
    super.initState();
    _wishlistController.ensureLoaded();
  }

  Future<void> _toggleFavorite() async {
    try {
      final bool? result = await _wishlistController.toggleFavorite(
        type: FavoriteType.city,
        rawItemId: widget.destination.id,
        fallbackName: widget.destination.name,
      );
      if (!mounted || result != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to update wishlist.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update wishlist failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final RecommendDestination dest = widget.destination;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.exploreSearchResult, extra: dest.name),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(20),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Image.network(
                      dest.imagePath,
                      width: double.infinity,
                      height: 162,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 162,
                        color: const Color(0xFFD8F2FD),
                        child: const Center(
                          child: Icon(
                            Icons.landscape_rounded,
                            size: 42,
                            color: Color(0xFF2EA7F8),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: _wishlistController,
                        builder: (BuildContext context, Widget? child) {
                          final bool isFavorite = _wishlistController
                              .isFavorite(
                                type: FavoriteType.city,
                                rawItemId: dest.id,
                              );
                          return GestureDetector(
                            onTap: _toggleFavorite,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: isFavorite
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dest.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2EA7F8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dest.shortDescription,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
