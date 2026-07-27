import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/home/data/home_repository.dart';
import 'package:hellovietnam/features/recommend/domain/recommend_destination.dart';

typedef HomeFeaturedLoader = Future<HomeFeaturedContent> Function();
typedef HomeCandidateLoader = Future<List<RecommendDestination>> Function();
typedef HomeClock = DateTime Function();

class HomeRefreshOutcome {
  const HomeRefreshOutcome({this.featuredError, this.personalizedError});

  final Object? featuredError;
  final Object? personalizedError;

  bool get hasError => featuredError != null || personalizedError != null;
}

class HomeContentController extends ChangeNotifier {
  HomeContentController({
    required HomeFeaturedLoader loadFeatured,
    required HomeCandidateLoader loadCandidates,
    HomeClock? clock,
    Duration freshnessWindow = const Duration(minutes: 2),
  }) : _loadFeatured = loadFeatured,
       _loadCandidates = loadCandidates,
       _clock = clock ?? DateTime.now,
       _freshnessWindow = freshnessWindow;

  final HomeFeaturedLoader _loadFeatured;
  final HomeCandidateLoader _loadCandidates;
  final HomeClock _clock;
  final Duration _freshnessWindow;

  HomeFeaturedContent? _featured;
  List<RecommendDestination>? _candidates;
  Object? _featuredError;
  Object? _personalizedError;
  DateTime? _featuredLoadedAt;
  Future<HomeRefreshOutcome>? _activeRefresh;
  bool _isInitialLoading = false;
  bool _isRefreshing = false;

  HomeFeaturedContent? get featured => _featured;
  List<RecommendDestination>? get candidates => _candidates;
  Object? get featuredError => _featuredError;
  Object? get personalizedError => _personalizedError;
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;

  Future<HomeRefreshOutcome> loadInitial() {
    if (_activeRefresh != null) return _activeRefresh!;
    _isInitialLoading = _featured == null && _candidates == null;
    notifyListeners();
    return _beginRefresh();
  }

  Future<HomeRefreshOutcome> refreshAll() {
    if (_activeRefresh != null) return _activeRefresh!;
    return _beginRefresh();
  }

  Future<HomeRefreshOutcome?> refreshIfStale() {
    final DateTime? loadedAt = _featuredLoadedAt;
    if (loadedAt != null && _clock().difference(loadedAt) < _freshnessWindow) {
      return Future<HomeRefreshOutcome?>.value(null);
    }
    return refreshAll();
  }

  Future<Object?> retryFeatured() async {
    final Object? error = await _refreshFeatured();
    notifyListeners();
    return error;
  }

  Future<Object?> retryPersonalized() async {
    final Object? error = await _refreshCandidates();
    notifyListeners();
    return error;
  }

  Future<HomeRefreshOutcome> _beginRefresh() {
    final Future<HomeRefreshOutcome> refresh = _refresh();
    _activeRefresh = refresh;
    refresh.whenComplete(() {
      if (identical(_activeRefresh, refresh)) {
        _activeRefresh = null;
      }
    });
    return refresh;
  }

  Future<HomeRefreshOutcome> _refresh() async {
    _isRefreshing = true;
    notifyListeners();

    final List<Object?> errors = await Future.wait<Object?>(<Future<Object?>>[
      _refreshFeatured(),
      _refreshCandidates(),
    ]);

    _isRefreshing = false;
    _isInitialLoading = false;
    notifyListeners();
    return HomeRefreshOutcome(
      featuredError: errors[0],
      personalizedError: errors[1],
    );
  }

  Future<Object?> _refreshFeatured() async {
    try {
      final HomeFeaturedContent result = await _loadFeatured();
      _featured = result;
      _featuredError = null;
      _featuredLoadedAt = _clock();
      return null;
    } catch (error) {
      _featuredError = error;
      return error;
    }
  }

  Future<Object?> _refreshCandidates() async {
    try {
      final List<RecommendDestination> result = await _loadCandidates();
      _candidates = result;
      _personalizedError = null;
      return null;
    } catch (error) {
      _personalizedError = error;
      return error;
    }
  }
}
