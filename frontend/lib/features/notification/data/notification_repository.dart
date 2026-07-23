import 'package:hellovietnam/features/notification/data/notification_api.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';

class NotificationPageResult {
  const NotificationPageResult({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;
}

abstract interface class NotificationRepository {
  Future<NotificationPageResult> fetchPage({int limit = 20, String? cursor});
  Future<int> fetchUnreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> registerDevice({
    required String fcmToken,
    required String installationId,
    required String platform,
  });
  Future<void> unregisterDevice(String installationId);
  Future<List<NotificationPreference>> fetchPreferences();
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  );
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({NotificationApi? api})
    : _api = api ?? SupabaseNotificationApi();

  static final SupabaseNotificationRepository instance =
      SupabaseNotificationRepository();

  final NotificationApi _api;

  @override
  Future<NotificationPageResult> fetchPage({
    int limit = 20,
    String? cursor,
  }) async {
    final Map<String, dynamic> response = await _api.invoke(
      'list',
      body: <String, Object?>{
        'limit': limit,
        'cursor': ?cursor,
      },
    );
    final List<dynamic> rawItems =
        response['items'] as List<dynamic>? ?? const [];
    return NotificationPageResult(
      items: rawItems
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> row) => AppNotification.fromJson(
              row.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false),
      nextCursor: response['nextCursor']?.toString(),
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    final Map<String, dynamic> response = await _api.invoke('unread-count');
    return (response['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await _api.invoke(
      'mark-read',
      body: <String, Object?>{'notificationId': id},
    );
  }

  @override
  Future<void> markAllRead() async {
    await _api.invoke('mark-all-read');
  }

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required String installationId,
    required String platform,
  }) async {
    await _api.invoke(
      'register-device',
      body: <String, Object?>{
        'fcmToken': fcmToken,
        'installationId': installationId,
        'platform': platform,
      },
    );
  }

  @override
  Future<void> unregisterDevice(String installationId) async {
    await _api.invoke(
      'unregister-device',
      body: <String, Object?>{'installationId': installationId},
    );
  }

  @override
  Future<List<NotificationPreference>> fetchPreferences() async {
    final Map<String, dynamic> response = await _api.invoke('get-preferences');
    final List<dynamic> rows =
        response['preferences'] as List<dynamic>? ?? const [];
    return rows
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> row) => NotificationPreference.fromJson(
            row.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async {
    final Map<String, dynamic> response = await _api.invoke(
      'update-preference',
      body: <String, Object?>{
        'notificationType': preference.type.name,
        'pushEnabled': preference.pushEnabled,
        'inAppEnabled': preference.inAppEnabled,
      },
    );
    final dynamic raw = response['preference'];
    if (raw is! Map) {
      throw StateError('Notification preference response is invalid.');
    }
    return NotificationPreference.fromJson(
      raw.map((dynamic key, dynamic value) => MapEntry(key.toString(), value)),
    );
  }
}
