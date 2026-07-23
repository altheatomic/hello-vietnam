import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/notification/application/notification_preferences_controller.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';

void main() {
  test('loads defaults for preference rows omitted by the backend', () async {
    final _FakeNotificationRepository repository = _FakeNotificationRepository(
      preferences: const <NotificationPreference>[
        NotificationPreference(
          type: NotificationPreferenceType.all,
          pushEnabled: false,
          inAppEnabled: true,
        ),
      ],
    );
    final NotificationPreferencesController controller =
        NotificationPreferencesController(repository: repository);

    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(
      controller.preference(NotificationPreferenceType.all).pushEnabled,
      isFalse,
    );
    expect(
      controller.preference(NotificationPreferenceType.forum).pushEnabled,
      isTrue,
    );
    expect(
      controller.effectivePushEnabled(NotificationPreferenceType.forum),
      isFalse,
    );
  });

  test('updates one type without changing the other preferences', () async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final NotificationPreferencesController controller =
        NotificationPreferencesController(repository: repository);
    await controller.load();

    await controller.setPushEnabled(NotificationPreferenceType.loyalty, false);

    expect(
      controller.preference(NotificationPreferenceType.loyalty).pushEnabled,
      isFalse,
    );
    expect(
      controller.preference(NotificationPreferenceType.forum).pushEnabled,
      isTrue,
    );
    expect(repository.updated.single.type, NotificationPreferenceType.loyalty);
  });

  test('rolls back an optimistic update when persistence fails', () async {
    final _FakeNotificationRepository repository = _FakeNotificationRepository(
      failUpdates: true,
    );
    final NotificationPreferencesController controller =
        NotificationPreferencesController(repository: repository);
    await controller.load();

    await expectLater(
      controller.setPushEnabled(NotificationPreferenceType.trip, false),
      throwsStateError,
    );

    expect(
      controller.preference(NotificationPreferenceType.trip).pushEnabled,
      isTrue,
    );
    expect(controller.errorMessage, isNotNull);
  });

  test('reset clears preferences loaded for the previous user', () async {
    final NotificationPreferencesController controller =
        NotificationPreferencesController(
          repository: _FakeNotificationRepository(
            preferences: const <NotificationPreference>[
              NotificationPreference(
                type: NotificationPreferenceType.all,
                pushEnabled: false,
                inAppEnabled: true,
              ),
            ],
          ),
        );
    await controller.load();

    controller.reset();

    expect(controller.isLoaded, isFalse);
    expect(controller.errorMessage, isNull);
    expect(
      controller.preference(NotificationPreferenceType.all).pushEnabled,
      isTrue,
    );
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({
    this.preferences = const <NotificationPreference>[],
    this.failUpdates = false,
  });

  final List<NotificationPreference> preferences;
  final bool failUpdates;
  final List<NotificationPreference> updated = <NotificationPreference>[];

  @override
  Future<List<NotificationPreference>> fetchPreferences() async => preferences;

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async {
    updated.add(preference);
    if (failUpdates) throw StateError('save failed');
    return preference;
  }

  @override
  Future<NotificationPageResult> fetchPage({int limit = 20, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<int> fetchUnreadCount() => throw UnimplementedError();

  @override
  Future<void> markAllRead() => throw UnimplementedError();

  @override
  Future<void> markRead(String id) => throw UnimplementedError();

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required String installationId,
    required String platform,
  }) => throw UnimplementedError();

  @override
  Future<void> unregisterDevice(String installationId) =>
      throw UnimplementedError();
}
