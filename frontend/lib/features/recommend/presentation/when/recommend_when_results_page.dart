import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[
                    Color(0xFF020B10),
                    Color(0xFF07161D),
                    Color(0xFF020B10),
                  ]
                : <Color>[
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
                      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 2),
                      child: Row(
                        children: <Widget>[
                          _TopCircleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              'Recommendation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFF87CEEB)
                                    : const Color(0xFF2EA7F8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: _EditableDateCard(
                        rangeLabel: _rangeLabel,
                        durationLabel: _durationLabel,
                        onTap: () =>
                            context.push(AppRoutes.recommendWhenCalendar),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: results.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _SuggestionCard(destination: results[index]);
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 19,
            color: isDark
                ? Theme.of(context).colorScheme.onSurface
                : const Color(0xFF64748B),
          ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryText = Theme.of(context).colorScheme.onSurface;
    final Color mutedText = isDark
        ? const Color(0xFF8FA8B4)
        : const Color(0xFF94A3B8);
    final Color accentColor = isDark
        ? const Color(0xFF87CEEB)
        : const Color(0xFF2EA7F8);
    final Color darkControlSurface = const Color(0xFF102832);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF07161D).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF87CEEB).withValues(alpha: 0.14)
                  : const Color(0xFFCDEDF9),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                blurRadius: isDark ? 18 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? darkControlSurface.withValues(alpha: 0.92)
                      : const Color(0xFFE7F8FE),
                  borderRadius: BorderRadius.circular(16),
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                      : null,
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rangeLabel,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      durationLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? darkControlSurface.withValues(alpha: 0.92)
                      : const Color(0xFFEAF8FE),
                  shape: BoxShape.circle,
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                      : null,
                ),
                child: Icon(Icons.edit_outlined, size: 19, color: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
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
        SnackBar(
          content: Text(context.l10n.ui('Please sign in to update wishlist.')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.ui('Update wishlist failed')}: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final RecommendDestination dest = widget.destination;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark
        ? const Color(0xFF87CEEB)
        : const Color(0xFF2EA7F8);
    final Color bodyTextColor = isDark
        ? const Color(0xFF8FA8B4)
        : const Color(0xFF64748B);
    const double cardRadius = 22;
    const double imageHeight = 138;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.exploreSearchResult, extra: dest.name),
        borderRadius: BorderRadius.circular(cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF07161D).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF87CEEB).withValues(alpha: 0.10)
                  : const Color(0xFFE7F6FC),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Image.network(
                      dest.imagePath,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: imageHeight,
                        color: isDark
                            ? const Color(0xFF102832)
                            : const Color(0xFFD8F2FD),
                        child: Center(
                          child: Icon(
                            Icons.landscape_rounded,
                            size: 42,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
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
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF102832,
                                      ).withValues(alpha: 0.88)
                                    : Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(
                                          0xFF87CEEB,
                                        ).withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.62),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.20 : 0.08,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 22,
                                color: isFavorite
                                    ? const Color(0xFFEF4444)
                                    : (isDark
                                          ? const Color(0xFFA9BCC7)
                                          : const Color(0xFF94A3B8)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dest.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dest.shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: bodyTextColor,
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
