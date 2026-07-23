import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/features/notification/application/notification_preferences_controller.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';
import 'package:hellovietnam/features/notification/presentation/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('shows master and category push preferences', (
    WidgetTester tester,
  ) async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final NotificationPreferencesController controller =
        NotificationPreferencesController(repository: repository);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: NotificationSettingsPage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Android notifications'), findsOneWidget);
    expect(find.text('Loyalty rewards'), findsOneWidget);
    expect(find.text('Forum activity'), findsOneWidget);
    expect(find.text('Vouchers'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('category switch persists only that category', (
    WidgetTester tester,
  ) async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final NotificationPreferencesController controller =
        NotificationPreferencesController(repository: repository);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController.instance,
        child: MaterialApp(
          home: NotificationSettingsPage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder loyaltySwitch = find.byKey(
      const ValueKey<String>('notification-switch-loyalty'),
    );
    expect(tester.widget<Switch>(loyaltySwitch).value, isTrue);

    await tester.tap(loyaltySwitch);
    await tester.pumpAndSettle();

    expect(repository.updated.single.type, NotificationPreferenceType.loyalty);
    expect(repository.updated.single.pushEnabled, isFalse);
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  final List<NotificationPreference> updated = <NotificationPreference>[];

  @override
  Future<List<NotificationPreference>> fetchPreferences() async =>
      const <NotificationPreference>[];

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async {
    updated.add(preference);
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
