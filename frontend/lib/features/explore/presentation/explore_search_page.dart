import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';

/// Mock list of searchable destinations — swap with API later.
const List<String> _allDestinations = [
  'Ha Noi',
  'Ho Chi Minh City',
  'Hue',
  'Hoi An',
  'Da Nang',
  'Da Lat',
  'Nha Trang',
  'Phu Quoc',
  'Sapa',
  'Ha Long Bay',
  'Can Tho',
  'Ninh Binh',
  'Quy Nhon',
  'Vung Tau',
  'Mui Ne',
];

class ExploreSearchPage extends StatefulWidget {
  const ExploreSearchPage({super.key});

  @override
  State<ExploreSearchPage> createState() => _ExploreSearchPageState();
}

class _ExploreSearchPageState extends State<ExploreSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field so keyboard opens immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _suggestions = [];
      } else {
        _suggestions = _allDestinations
            .where((d) => d.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _onSubmit(String query) {
    if (query.trim().isEmpty) return;
    context.push(AppRoutes.exploreSearchResult, extra: query.trim());
  }

  void _onSuggestionTap(String destination) {
    _controller.text = destination;
    context.push(AppRoutes.exploreSearchResult, extra: destination);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Top bar: back + search ─────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              statusBarH + 8,
              AppConstants.pagePadding,
              12,
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                Expanded(
                  child: SearchBarWidget(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    showFilterButton: false,
                    hintText: context.l10n.ui('Search for destinations'),
                    onChanged: _onChanged,
                    onSearch: _onSubmit,
                  ),
                ),
              ],
            ),
          ),

          // ── Suggestions list ───────────────────────────
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: theme.dividerColor,
                indent: AppConstants.pagePadding,
                endIndent: AppConstants.pagePadding,
              ),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () => _onSuggestionTap(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.pagePadding,
                      vertical: 14,
                    ),
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
