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

  /// Defers [notifyListeners] out of the current synchronous call stack.
  ///
  /// This controller is a singleton with `ListenableBuilder`s mounted on
  /// multiple simultaneously-live routes (e.g. Home's bell-icon badge stays
  /// mounted underneath a pushed NotificationPage). Calling
  /// [notifyListeners] synchronously — e.g. from `initState()` — can land
  /// inside another route's build phase and trigger
  /// "setState()/markNeedsBuild() called during build". `Future.microtask`
  /// (rather than `WidgetsBinding.instance.addPostFrameCallback`) is used
  /// here specifically because this controller is unit-tested with plain
  /// `test()` blocks that never initialize a Flutter binding or pump a
  /// frame — a microtask still escapes the current build-phase call stack
  /// without depending on Flutter's binding/frame scheduling.
  void _notify() {
    Future.microtask(() {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> loadInitial() => _replaceAll();

  Future<void> refresh() => _replaceAll();

  Future<void> _replaceAll() async {
    final int generation = ++_requestGeneration;
    _isInitialLoading = _items.isEmpty;
    _errorMessage = null;
    _notify();
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
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    final String? cursor = _nextCursor;
    if (_isLoadingMore || cursor == null) return;
    final int generation = _requestGeneration;
    _isLoadingMore = true;
    _errorMessage = null;
    _notify();
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
        _notify();
      }
    }
  }

  Future<void> markRead(String id) async {
    final int index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;
    final AppNotification previous = _items[index];
    _items[index] = previous.copyWith(isRead: true);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    _notify();
    try {
      await _repository.markRead(id);
    } catch (_) {
      _items[index] = previous;
      _unreadCount += 1;
      _notify();
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
    _notify();
    try {
      await _repository.markAllRead();
    } catch (_) {
      _items
        ..clear()
        ..addAll(previous);
      _unreadCount = previousCount;
      _notify();
      rethrow;
    }
  }

  void notifyPushReceived() {
    _unreadCount += 1;
    _notify();
  }

  void reset() {
    _requestGeneration += 1;
    _items.clear();
    _nextCursor = null;
    _errorMessage = null;
    _unreadCount = 0;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _notify();
  }

  List<AppNotification> _dedupe(List<AppNotification> values) {
    final Set<String> ids = <String>{};
    return values.where((item) => ids.add(item.id)).toList(growable: false);
  }
}
