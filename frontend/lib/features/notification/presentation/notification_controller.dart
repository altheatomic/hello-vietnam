import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({NotificationRepository? repository})
    : _repository = repository ?? MockNotificationRepository.instance;

  final NotificationRepository _repository;

  bool _isLoading = true;
  String? _errorMessage;
  List<AppNotification> _notifications = <AppNotification>[];
  Set<NotificationFilter> _activeFilters = <NotificationFilter>{};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);
  Set<NotificationFilter> get activeFilters =>
      Set<NotificationFilter>.unmodifiable(_activeFilters);

  List<AppNotification> get visibleNotifications {
    if (_activeFilters.isEmpty) {
      return notifications;
    }
    return _notifications
        .where(
          (notification) =>
              _activeFilters.any((filter) => filter.matches(notification.type)),
        )
        .toList(growable: false);
  }

  int get activeFilterCount => _activeFilters.length;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _repository.fetchNotifications();
    } catch (_) {
      _errorMessage = 'Unable to load notifications right now.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    _notifications = await _repository.markAsRead(id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications = await _repository.clearAll();
    notifyListeners();
  }

  void applyFilters(Set<NotificationFilter> filters) {
    _activeFilters = Set<NotificationFilter>.from(filters)
      ..remove(NotificationFilter.all);
    notifyListeners();
  }

  void resetFilters() {
    _activeFilters = <NotificationFilter>{};
    notifyListeners();
  }
}
