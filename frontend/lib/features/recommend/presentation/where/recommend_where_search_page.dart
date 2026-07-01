import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    try {
      final data = await RecommendRepository().getPersonalizedProvinces();
      if (!mounted) return;
      setState(() {
        _allDestinations = data;
        _results = _filter(widget.initialQuery);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fallback to mock data when API is unavailable
      setState(() {
        _allDestinations = mockRecommendDestinations;
        _results = _filter(widget.initialQuery);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<RecommendDestination> _filter(String query) {
    if (query.trim().isEmpty) return _allDestinations;
    final q = query.toLowerCase();
    return _allDestinations
        .where((d) => d.name.toLowerCase().contains(q))
        .toList();
  }

  void _onChanged(String value) => setState(() => _results = _filter(value));

  void _clearQuery() {
    _controller.clear();
    _onChanged('');
  }

  void _openDestination(String destination) {
    if (destination.trim().isEmpty) return;
    RecommendDestination? match;
    for (final candidate in _allDestinations) {
      if (candidate.name.toLowerCase() == destination.trim().toLowerCase()) {
        match = candidate;
        break;
      }
    }

    context.push(
      AppRoutes.cityDetail,
      extra: CityDetailRequest(
        id: match?.id ?? destination.trim().toLowerCase().replaceAll(' ', '-'),
        name: match?.name ?? destination.trim(),
        idProvince: match?.id,
        fallbackImages: <String>[
          if (match != null) match.imagePath,
          if (match != null) ...match.gallery,
        ],
        fallbackImagePath: match?.imagePath,
        fallbackRating: match?.rating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Search header (white, not blue — matches Figma 1.2) ──
          Container(
            color: Colors.white,
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
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(45),
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _openDestination,
                      decoration: InputDecoration(
                        hintText: 'Search destination',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? GestureDetector(
                                onTap: _clearQuery,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

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
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 62,
                      endIndent: AppConstants.pagePadding,
                      color: AppColors.divider,
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
                          dest.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          dest.tags.join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
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
