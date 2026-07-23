import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';

class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController({NotificationRepository? repository})
    : _repository = repository ?? SupabaseNotificationRepository.instance;

  static final NotificationInboxController instance =
      NotificationInboxController();

  final NotificationRepository _repository;
  final List<AppNotification> _items = <AppNotification>[];

  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _nextCursor;
  String? _errorMessage;
  int _unreadCount = 0;
  int _requestGeneration = 0;

  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _nextCursor != null;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  Future<void> loadInitial() => _replaceAll();

  Future<void> refresh() => _replaceAll();

  Future<void> _replaceAll() async {
    final int generation = ++_requestGeneration;
    _isInitialLoading = _items.isEmpty;
    _errorMessage = null;
    notifyListeners();
    try {
      final List<Object> result = await Future.wait<Object>(<Future<Object>>[
        _repository.fetchPage(),
        _repository.fetchUnreadCount(),
      ]);
      if (generation != _requestGeneration) return;
      final NotificationPageResult page = result[0] as NotificationPageResult;
      _items
        ..clear()
        ..addAll(_dedupe(page.items));
      _nextCursor = page.nextCursor;
      _unreadCount = result[1] as int;
    } catch (error) {
      if (generation == _requestGeneration) {
        _errorMessage = error.toString();
      }
    } finally {
      if (generation == _requestGeneration) {
        _isInitialLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final String? cursor = _nextCursor;
    if (_isLoadingMore || cursor == null) return;
    final int generation = _requestGeneration;
    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final NotificationPageResult page = await _repository.fetchPage(
        cursor: cursor,
      );
      if (generation != _requestGeneration) return;
      final Set<String> ids = _items.map((item) => item.id).toSet();
      _items.addAll(page.items.where((item) => ids.add(item.id)));
      _nextCursor = page.nextCursor;
    } catch (error) {
      if (generation == _requestGeneration) {
        _errorMessage = error.toString();
      }
    } finally {
      if (generation == _requestGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> markRead(String id) async {
    final int index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;
    final AppNotification previous = _items[index];
    _items[index] = previous.copyWith(isRead: true);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    notifyListeners();
    try {
      await _repository.markRead(id);
    } catch (_) {
      _items[index] = previous;
      _unreadCount += 1;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final List<AppNotification> previous = List<AppNotification>.from(_items);
    final int previousCount = _unreadCount;
    for (int index = 0; index < _items.length; index += 1) {
      _items[index] = _items[index].copyWith(isRead: true);
    }
    _unreadCount = 0;
    notifyListeners();
    try {
      await _repository.markAllRead();
    } catch (_) {
      _items
        ..clear()
        ..addAll(previous);
      _unreadCount = previousCount;
      notifyListeners();
      rethrow;
    }
  }

  void notifyPushReceived() {
    _unreadCount += 1;
    notifyListeners();
  }

  void reset() {
    _requestGeneration += 1;
    _items.clear();
    _nextCursor = null;
    _errorMessage = null;
    _unreadCount = 0;
    _isInitialLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  List<AppNotification> _dedupe(List<AppNotification> values) {
    final Set<String> ids = <String>{};
    return values.where((item) => ids.add(item.id)).toList(growable: false);
  }
}
