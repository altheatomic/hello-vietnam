import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/notification/application/push_notification_service.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';

void main() {
  test('converts the FCM data payload into an actionable notification', () {
    const PushNotificationMessage message = PushNotificationMessage(
      notificationId: 'notification-1',
      title: 'New reply',
      body: 'Someone replied to your post.',
      data: <String, String>{
        'id_notification': 'notification-1',
        'notification_type': 'forum',
        'target':
            '{"kind":"forumPost","entityId":"post-1","entityName":"Post"}',
      },
    );

    final AppNotification notification = message.toAppNotification();

    expect(notification.id, 'notification-1');
    expect(notification.type, AppNotificationType.forum);
    expect(notification.target.kind, NotificationTargetKind.forumPost);
    expect(notification.target.entityId, 'post-1');
  });

  test(
    'registers the current installation after permission is granted',
    () async {
      final _FakeMessagingGateway messaging = _FakeMessagingGateway(
        token: 'fcm-token',
      );
      final _FakeNotificationRepository repository =
          _FakeNotificationRepository();
      final PushNotificationService service = PushNotificationService(
        messaging: messaging,
        localNotifications: _FakeLocalNotificationGateway(),
        repository: repository,
        installationIdProvider: _FakeInstallationIdProvider('installation-1'),
        currentUserId: () => 'user-1',
        isSupportedPlatform: true,
      );

      await service.initialize();

      expect(messaging.initializeCount, 1);
      expect(repository.registeredTokens, <String>['fcm-token']);
      expect(repository.registeredInstallations, <String>['installation-1']);
    },
  );

  test('shows a foreground notification and refreshes the inbox', () async {
    final _FakeMessagingGateway messaging = _FakeMessagingGateway(
      token: 'fcm-token',
    );
    final _FakeLocalNotificationGateway local = _FakeLocalNotificationGateway();
    int receivedCount = 0;
    final PushNotificationService service = PushNotificationService(
      messaging: messaging,
      localNotifications: local,
      repository: _FakeNotificationRepository(),
      installationIdProvider: _FakeInstallationIdProvider('installation-1'),
      currentUserId: () => 'user-1',
      isSupportedPlatform: true,
      onNotificationReceived: () => receivedCount += 1,
    );
    await service.initialize();

    messaging.foregroundController.add(
      const PushNotificationMessage(
        notificationId: 'notification-1',
        title: 'Reward earned',
        body: 'You received 10 points.',
        data: <String, String>{'notification_type': 'loyalty'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(local.shownMessages, hasLength(1));
    expect(receivedCount, 1);
  });

  test('unregisters the installation before sign out', () async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final PushNotificationService service = PushNotificationService(
      messaging: _FakeMessagingGateway(token: 'fcm-token'),
      localNotifications: _FakeLocalNotificationGateway(),
      repository: repository,
      installationIdProvider: _FakeInstallationIdProvider('installation-1'),
      currentUserId: () => 'user-1',
      isSupportedPlatform: true,
    );
    await service.initialize();

    await service.unregisterCurrentDevice();

    expect(repository.unregisteredInstallations, <String>['installation-1']);
  });

  test('does not initialize Firebase on unsupported platforms', () async {
    final _FakeMessagingGateway messaging = _FakeMessagingGateway(
      token: 'fcm-token',
    );
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final PushNotificationService service = PushNotificationService(
      messaging: messaging,
      localNotifications: _FakeLocalNotificationGateway(),
      repository: repository,
      installationIdProvider: _FakeInstallationIdProvider('installation-1'),
      currentUserId: () => 'user-1',
      isSupportedPlatform: false,
    );

    await service.initialize();

    expect(messaging.initializeCount, 0);
    expect(repository.registeredTokens, isEmpty);
  });
}

class _FakeMessagingGateway implements PushMessagingGateway {
  _FakeMessagingGateway({required this.token});

  final String? token;
  int initializeCount = 0;
  final StreamController<PushNotificationMessage> foregroundController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<PushNotificationMessage> openedController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<String> tokenController =
      StreamController<String>.broadcast();

  @override
  Stream<PushNotificationMessage> get foregroundMessages =>
      foregroundController.stream;

  @override
  Stream<PushNotificationMessage> get openedMessages => openedController.stream;

  @override
  Stream<String> get tokenRefreshes => tokenController.stream;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<PushNotificationMessage?> getInitialMessage() async => null;

  @override
  Future<void> initialize() async => initializeCount += 1;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.authorized;
}

class _FakeLocalNotificationGateway implements LocalNotificationGateway {
  final List<PushNotificationMessage> shownMessages =
      <PushNotificationMessage>[];

  @override
  Future<void> initialize(
    Future<void> Function(PushNotificationMessage message) onTap,
  ) async {}

  @override
  Future<void> show(PushNotificationMessage message) async {
    shownMessages.add(message);
  }
}

class _FakeInstallationIdProvider implements InstallationIdProvider {
  _FakeInstallationIdProvider(this.value);

  final String value;

  @override
  Future<String> getOrCreate() async => value;
}

class _FakeNotificationRepository implements NotificationRepository {
  final List<String> registeredTokens = <String>[];
  final List<String> registeredInstallations = <String>[];
  final List<String> unregisteredInstallations = <String>[];

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required String installationId,
    required String platform,
  }) async {
    registeredTokens.add(fcmToken);
    registeredInstallations.add(installationId);
  }

  @override
  Future<void> unregisterDevice(String installationId) async {
    unregisteredInstallations.add(installationId);
  }

  @override
  Future<NotificationPageResult> fetchPage({
    int limit = 20,
    String? cursor,
  }) async => const NotificationPageResult(items: <AppNotification>[]);

  @override
  Future<List<NotificationPreference>> fetchPreferences() async =>
      <NotificationPreference>[];

  @override
  Future<int> fetchUnreadCount() async => 0;

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async => preference;
}
