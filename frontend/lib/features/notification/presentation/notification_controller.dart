import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/notification/application/notification_inbox_controller.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({NotificationInboxController? inbox})
    : _inbox = inbox ?? NotificationInboxController.instance {
    _inbox.addListener(_forwardChanges);
  }

  final NotificationInboxController _inbox;
  Set<NotificationFilter> _activeFilters = <NotificationFilter>{};

  bool get isLoading => _inbox.isInitialLoading;
  bool get isLoadingMore => _inbox.isLoadingMore;
  bool get hasMore => _inbox.hasMore;
  String? get errorMessage => _inbox.errorMessage;
  List<AppNotification> get notifications => _inbox.items;
  Set<NotificationFilter> get activeFilters =>
      Set<NotificationFilter>.unmodifiable(_activeFilters);

  List<AppNotification> get visibleNotifications {
    if (_activeFilters.isEmpty) return notifications;
    return notifications
        .where(
          (AppNotification notification) => _activeFilters.any(
            (NotificationFilter filter) => filter.matches(notification.type),
          ),
        )
        .toList(growable: false);
  }

  int get activeFilterCount => _activeFilters.length;

  Future<void> load() => _inbox.loadInitial();
  Future<void> refresh() => _inbox.refresh();
  Future<void> loadMore() => _inbox.loadMore();
  Future<void> markAsRead(String id) => _inbox.markRead(id);
  Future<void> clearAll() => _inbox.markAllRead();

  void applyFilters(Set<NotificationFilter> filters) {
    _activeFilters = Set<NotificationFilter>.from(filters)
      ..remove(NotificationFilter.all);
    notifyListeners();
  }

  void resetFilters() {
    _activeFilters = <NotificationFilter>{};
    notifyListeners();
  }

  void _forwardChanges() => notifyListeners();

  @override
  void dispose() {
    _inbox.removeListener(_forwardChanges);
    super.dispose();
  }
}
