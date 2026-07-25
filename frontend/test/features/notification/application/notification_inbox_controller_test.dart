import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/notification/application/notification_inbox_controller.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';

void main() {
  test(
    'deduplicates pages and prevents concurrent load-more requests',
    () async {
      final _FakeNotificationRepository repository =
          _FakeNotificationRepository(
            pages: <NotificationPageResult>[
              NotificationPageResult(
                items: <AppNotification>[_notification('one')],
                nextCursor: 'cursor-1',
              ),
              NotificationPageResult(
                items: <AppNotification>[
                  _notification('one'),
                  _notification('two'),
                ],
                nextCursor: null,
              ),
            ],
          );
      final NotificationInboxController controller =
          NotificationInboxController(repository: repository);

      await controller.loadInitial();
      await Future.wait(<Future<void>>[
        controller.loadMore(),
        controller.loadMore(),
      ]);

      expect(controller.items.map((item) => item.id), <String>['one', 'two']);
      expect(repository.fetchCalls, 2);
      expect(controller.hasMore, isFalse);
    },
  );

  test('late initial request cannot overwrite a newer refresh', () async {
    final Completer<NotificationPageResult> first =
        Completer<NotificationPageResult>();
    final _FakeNotificationRepository repository = _FakeNotificationRepository(
      pendingPages: <Future<NotificationPageResult>>[
        first.future,
        Future<NotificationPageResult>.value(
          NotificationPageResult(
            items: <AppNotification>[_notification('new')],
            nextCursor: null,
          ),
        ),
      ],
    );
    final NotificationInboxController controller = NotificationInboxController(
      repository: repository,
    );

    final Future<void> initial = controller.loadInitial();
    await controller.refresh();
    first.complete(
      NotificationPageResult(
        items: <AppNotification>[_notification('old')],
        nextCursor: null,
      ),
    );
    await initial;

    expect(controller.items.single.id, 'new');
  });
}

AppNotification _notification(String id) => AppNotification(
  id: id,
  type: AppNotificationType.account,
  icon: AppNotificationIcon.badge,
  title: id,
  description: id,
  timestampLabel: 'now',
  target: const NotificationTarget(kind: NotificationTargetKind.upgradeAccount),
);

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({
    this.pages = const <NotificationPageResult>[],
    this.pendingPages = const <Future<NotificationPageResult>>[],
  });

  final List<NotificationPageResult> pages;
  final List<Future<NotificationPageResult>> pendingPages;
  int fetchCalls = 0;

  @override
  Future<NotificationPageResult> fetchPage({int limit = 20, String? cursor}) {
    final int index = fetchCalls++;
    if (pendingPages.isNotEmpty) return pendingPages[index];
    return Future<NotificationPageResult>.value(pages[index]);
  }

  @override
  Future<int> fetchUnreadCount() async => 0;

  @override
  Future<List<NotificationPreference>> fetchPreferences() async =>
      const <NotificationPreference>[];

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required String installationId,
    required String platform,
  }) async {}

  @override
  Future<void> unregisterDevice(String installationId) async {}

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async => preference;
}
