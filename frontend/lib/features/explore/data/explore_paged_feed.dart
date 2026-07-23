import 'package:hellovietnam/features/explore/data/explore_repository.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

typedef ExplorePageLoader =
    Future<ExploreCategoryPageData> Function({
      required DetailCategory category,
      required int limit,
      required int offset,
    });

class ExplorePagedFeed {
  ExplorePagedFeed({
    required this.category,
    required this.loader,
    this.pageSize = 12,
  });

  final DetailCategory category;
  final ExplorePageLoader loader;
  final int pageSize;

  final List<ExploreItem> _items = <ExploreItem>[];
  int? _nextOffset = 0;
  bool _isLoading = false;
  bool _initialized = false;
  Object? _error;

  List<ExploreItem> get items => List<ExploreItem>.unmodifiable(_items);
  bool get hasMore => _nextOffset != null;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  Object? get error => _error;

  Future<void> loadInitial() async {
    if (_isLoading || _initialized) return;
    _items.clear();
    _nextOffset = 0;
    await _load(reset: true);
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _items.clear();
    _nextOffset = 0;
    _initialized = false;
    await _load(reset: true);
  }

  Future<void> loadMore() async {
    if (_isLoading || !_initialized || _nextOffset == null) return;
    await _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    final int offset = _nextOffset ?? 0;
    _isLoading = true;
    _error = null;
    try {
      final ExploreCategoryPageData page = await loader(
        category: category,
        limit: pageSize,
        offset: offset,
      );
      final Set<String> existingIds = _items
          .map((ExploreItem item) => item.id)
          .toSet();
      for (final ExploreItem item in page.items) {
        if (existingIds.add(item.id)) {
          _items.add(item);
        }
      }
      _nextOffset = page.nextOffset;
      _initialized = true;
    } catch (error) {
      _error = error;
      if (reset) {
        _initialized = true;
      }
    } finally {
      _isLoading = false;
    }
  }
}
