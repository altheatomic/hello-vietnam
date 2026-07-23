import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/notification/data/notification_api.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';

void main() {
  test(
    'maps server rows, loyalty type, safe icon, target, and cursor',
    () async {
      final _FakeNotificationApi api = _FakeNotificationApi(
        listResponse: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id_notification': 'notification-1',
              'notification_type': 'loyalty',
              'icon': 'not-a-real-icon',
              'title': 'Points earned',
              'body': 'You earned 10 points.',
              'created_at': '2026-07-22T10:00:00Z',
              'read_at': null,
              'payload_jsonb': <String, dynamic>{
                'target': <String, dynamic>{'kind': 'loyaltyRewards'},
              },
            },
          ],
          'nextCursor': '2026-07-22T10:00:00Z|notification-1',
        },
      );
      final NotificationRepository repository = SupabaseNotificationRepository(
        api: api,
      );

      final NotificationPageResult page = await repository.fetchPage();

      expect(page.items.single.type, AppNotificationType.loyalty);
      expect(page.items.single.icon, AppNotificationIcon.badge);
      expect(
        page.items.single.target.kind,
        NotificationTargetKind.loyaltyRewards,
      );
      expect(page.items.single.isRead, isFalse);
      expect(page.nextCursor, '2026-07-22T10:00:00Z|notification-1');
    },
  );

  test('merges all six notification preferences from the API', () async {
    final _FakeNotificationApi api = _FakeNotificationApi(
      preferencesResponse: <String, dynamic>{
        'preferences': <Map<String, dynamic>>[
          for (final String type in <String>[
            'all',
            'loyalty',
            'forum',
            'voucher',
            'trip',
            'account',
          ])
            <String, dynamic>{
              'id_user': 'user-1',
              'notification_type': type,
              'push_enabled': type != 'forum',
              'in_app_enabled': true,
            },
        ],
      },
    );
    final NotificationRepository repository = SupabaseNotificationRepository(
      api: api,
    );

    final preferences = await repository.fetchPreferences();

    expect(preferences, hasLength(6));
    expect(
      preferences.singleWhere((item) => item.type.name == 'forum').pushEnabled,
      isFalse,
    );
  });
}

class _FakeNotificationApi implements NotificationApi {
  _FakeNotificationApi({
    this.listResponse = const <String, dynamic>{},
    this.preferencesResponse = const <String, dynamic>{},
  });

  final Map<String, dynamic> listResponse;
  final Map<String, dynamic> preferencesResponse;

  @override
  Future<Map<String, dynamic>> invoke(
    String action, {
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    if (action == 'list') return listResponse;
    if (action == 'get-preferences') return preferencesResponse;
    return <String, dynamic>{};
  }
}
