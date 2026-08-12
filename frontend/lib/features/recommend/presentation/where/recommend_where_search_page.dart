import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import 'package:hellovietnam/core/utils/vietnamese_text_utils.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import '../../data/recommend_mock_data.dart';
import '../../data/recommend_repository.dart';
import '../../domain/recommend_destination.dart';

/// Recommendation 1.1 / 1.2 / 1.3 — single screen that covers:
///   • Initial state: full destination list (1.1)
///   • Focused search bar with keyboard open (1.2) — same widget, auto-focused
///   • Live-filtered results as the user types (1.3)
class RecommendWhereSearchPage extends StatefulWidget {
  const RecommendWhereSearchPage({super.key, this.initialQuery = ''});

  /// Pre-populated query when arriving from the entry page search bar.
  final String initialQuery;

  @override
  State<RecommendWhereSearchPage> createState() =>
      _RecommendWhereSearchPageState();
}

class _RecommendWhereSearchPageState extends State<RecommendWhereSearchPage> {
  late final TextEditingController _controller;
  List<RecommendDestination> _allDestinations = <RecommendDestination>[];
  List<RecommendDestination> _results = <RecommendDestination>[];
  bool _isLoading = true;
  // True whenever _allDestinations is currently mockRecommendDestinations
  // (getPersonalizedProvinces() failed) rather than real data from the DB.
  // mock ids are dev placeholder slugs (e.g. 'hochiminh', not a UUID) — see
  // recommend_mock_data.dart — so anything sourced from this list must never
  // be allowed to reach CityDetailPage/the API as if it were a real
  // id_province (see _openDestination()'s guard below).
  bool _isMockFallback = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    List<RecommendDestination> destinations;
    bool isMockFallback = false;
    try {
      destinations = await RecommendRepository().getPersonalizedProvinces();
    } catch (e) {
      debugPrint('RecommendWhereSearchPage: getPersonalizedProvinces failed: $e');
      destinations = mockRecommendDestinations;
      isMockFallback = true;
    }
    if (!mounted) return;
    setState(() {
      _allDestinations = destinations;
      _isMockFallback = isMockFallback;
      _results = _filter(widget.initialQuery);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<RecommendDestination> _filter(String query) {
    if (query.trim().isEmpty) return _allDestinations;
    return _allDestinations
        .where((d) => matchesSearchQuery(query, d.name))
        .toList();
  }

  void _onChanged(String value) => setState(() => _results = _filter(value));

  void _clearQuery() {
    _controller.clear();
    _onChanged('');
  }

  void _openDestination(String destination) {
    if (destination.trim().isEmpty) return;

    // _allDestinations is currently mockRecommendDestinations (dev
    // placeholder ids, not real UUIDs) because the real fetch failed — see
    // _loadDestinations(). Navigating from here would build a
    // CityDetailRequest with a fake id (e.g. 'hochiminh') that CityDetailPage
    // then sends straight to the province API as if it were a real
    // id_province, producing an opaque Postgres "invalid input syntax for
    // type uuid" error deep in a different screen. Block it here instead,
    // where the actual cause is known.
    if (_isMockFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.ui(
              "Couldn't load destinations. Please check your connection and try again.",
            ),
          ),
        ),
      );
      return;
    }

    final String normalizedDestination = removeVietnameseDiacritics(
      destination.trim(),
    ).toLowerCase();
    RecommendDestination? match;
    for (final candidate in _allDestinations) {
      if (removeVietnameseDiacritics(candidate.name).toLowerCase() ==
          normalizedDestination) {
        match = candidate;
        break;
      }
    }

    final request = CityDetailRequest(
      id: match?.id ?? destination.trim().toLowerCase().replaceAll(' ', '-'),
      name: match?.name ?? destination.trim(),
      fallbackImages: <String>[
        if (match != null) match.imagePath,
        if (match != null) ...match.gallery,
      ],
      fallbackImagePath: match?.imagePath,
      fallbackRating: match?.avgRating ?? match?.rating,
      description: match?.description,
    );

    context.push(AppRoutes.cityDetailPath(request));
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Search header (white, not blue — matches Figma 1.2) ──
          Container(
            color: isDark ? const Color(0xFF020B10) : Colors.white,
            padding: EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              statusBarHeight + 8,
              AppConstants.pagePadding,
              12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface.withValues(alpha: 0.92)
                          : AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(45),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _openDestination,
                      decoration: InputDecoration(
                        hintText: context.l10n.ui('Search destination'),
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _controller.text.isNotEmpty
                            ? GestureDetector(
                                onTap: _clearQuery,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // ── Results list ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    message:
                        'No destinations match "${_controller.text}".\nTry a different name.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 62,
                      endIndent: AppConstants.pagePadding,
                      color: theme.dividerColor,
                    ),
                    itemBuilder: (context, i) {
                      final dest = _results[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.pagePadding,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          removeVietnameseDiacritics(dest.name),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          dest.tags.join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        onTap: () => _openDestination(dest.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
