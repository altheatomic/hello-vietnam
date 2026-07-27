import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_province.dart';

class ExploreSearchPage extends StatefulWidget {
  const ExploreSearchPage({super.key});

  @override
  State<ExploreSearchPage> createState() => _ExploreSearchPageState();
}

class _ExploreSearchPageState extends State<ExploreSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ExploreProvince> _suggestions = <ExploreProvince>[];
  bool _isSearching = false;
  int _searchVersion = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    final int version = ++_searchVersion;
    final String trimmed = query.trim();
    _searchDebounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _suggestions = <ExploreProvince>[];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _suggestions = <ExploreProvince>[];
    });
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_searchLocal(trimmed, version));
    });
  }

  Future<void> _searchLocal(String query, int version) async {
    try {
      final List<ExploreProvince> results = await ExploreRepository.instance
          .searchProvinces(query);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _suggestions = <ExploreProvince>[];
        _isSearching = false;
      });
    }
  }

  Future<void> _onSubmit(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return;

    ExploreProvince? selected = _findExactSuggestion(trimmed);
    selected ??= await ExploreRepository.instance.resolveProvinceByName(
      trimmed,
    );
    if (!mounted) return;

    if (selected == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.ui(
                'Please choose a valid province or city suggestion.',
              ),
            ),
          ),
        );
      return;
    }

    context.push(AppRoutes.exploreSearchResult, extra: selected);
  }

  ExploreProvince? _findExactSuggestion(String query) {
    final String normalized = _normalizeText(query);
    for (final ExploreProvince suggestion in _suggestions) {
      if (_normalizeText(suggestion.name) == normalized) {
        return suggestion;
      }
    }
    if (_suggestions.length == 1) {
      return _suggestions.first;
    }
    return null;
  }

  void _onSuggestionTap(ExploreProvince destination) {
    _controller.text = destination.name;
    context.push(AppRoutes.exploreSearchResult, extra: destination);
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              statusBarH + 8,
              AppConstants.pagePadding,
              12,
            ),
            child: Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: AppColors.primary,
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
                    onChanged: (String value) {
                      _onChanged(value);
                    },
                    onSearch: (String value) {
                      _onSubmit(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isSearching)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
            ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
                indent: AppConstants.pagePadding,
                endIndent: AppConstants.pagePadding,
              ),
              itemBuilder: (context, index) {
                final ExploreProvince suggestion = _suggestions[index];

                return InkWell(
                  onTap: () => _onSuggestionTap(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.pagePadding,
                      vertical: 14,
                    ),
                    child: Text(
                      suggestion.name,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
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

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('Ä‘', 'd')
        .replaceAllMapped(
          RegExp(r'[Ã Ã¡áº¡áº£Ã£Ã¢áº§áº¥áº­áº©áº«Äƒáº±áº¯áº·áº³áºµ]'),
          (_) => 'a',
        )
        .replaceAllMapped(
          RegExp(r'[Ã¨Ã©áº¹áº»áº½Ãªá»áº¿á»‡á»ƒá»…]'),
          (_) => 'e',
        )
        .replaceAllMapped(RegExp(r'[Ã¬Ã­á»‹á»‰Ä©]'), (_) => 'i')
        .replaceAllMapped(
          RegExp(r'[Ã²Ã³á»á»ÃµÃ´á»“á»‘á»™á»•á»—Æ¡á»á»›á»£á»Ÿá»¡]'),
          (_) => 'o',
        )
        .replaceAllMapped(
          RegExp(r'[Ã¹Ãºá»¥á»§Å©Æ°á»«á»©á»±á»­á»¯]'),
          (_) => 'u',
        )
        .replaceAllMapped(RegExp(r'[á»³Ã½á»µá»·á»¹]'), (_) => 'y');
  }
}
