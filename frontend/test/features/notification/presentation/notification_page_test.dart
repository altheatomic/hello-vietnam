import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart';
import 'package:hellovietnam/features/notification/application/notification_inbox_controller.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';
import 'package:hellovietnam/features/notification/presentation/notification_controller.dart';
import 'package:hellovietnam/features/notification/presentation/notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.instance.initialize();
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('shows notifications supplied by the production controller', (
    WidgetTester tester,
  ) async {
    final NotificationController controller = _controllerWithPages(
      <NotificationPageResult>[
        NotificationPageResult(
          items: <AppNotification>[_notification('first')],
        ),
      ],
    );
    await tester.pumpWidget(_notificationTestApp(controller: controller));

    await tester.pumpAndSettle();

    expect(find.text('first'), findsWidgets);
  });

  testWidgets('loads the next page when scrolling near the end', (
    WidgetTester tester,
  ) async {
    final NotificationController controller = _controllerWithPages(
      <NotificationPageResult>[
        NotificationPageResult(
          items: List<AppNotification>.generate(
            16,
            (int index) => _notification('item-$index'),
          ),
          nextCursor: 'next-page',
        ),
        NotificationPageResult(
          items: <AppNotification>[_notification('loaded-later')],
        ),
      ],
    );
    await tester.pumpWidget(_notificationTestApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(ListView).last,
      const Offset(0, -2400),
      1600,
    );
    await tester.pumpAndSettle();

    expect(find.text('loaded-later'), findsWidgets);
  });

  testWidgets('uses a dark background gradient in dark mode', (
    WidgetTester tester,
  ) async {
    final NotificationController controller = _controllerWithPages(
      <NotificationPageResult>[
        NotificationPageResult(items: <AppNotification>[_notification('dark')]),
      ],
    );
    await tester.pumpWidget(
      _notificationTestApp(controller: controller, theme: buildDarkTheme()),
    );
    await tester.pump();

    final Iterable<DecoratedBox> darkBackgrounds = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((DecoratedBox box) {
          final Decoration decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.gradient is LinearGradient &&
              (decoration.gradient! as LinearGradient).colors.first
                      .computeLuminance() <
                  0.1;
        });
    expect(darkBackgrounds, isNotEmpty);
  });

  testWidgets('keeps loaded notifications visible when load more fails', (
    WidgetTester tester,
  ) async {
    final NotificationController controller = NotificationController(
      inbox: NotificationInboxController(
        repository: _FailingLoadMoreNotificationRepository(),
      ),
    );
    await tester.pumpWidget(_notificationTestApp(controller: controller));
    await tester.pumpAndSettle();

    await controller.loadMore();
    await tester.pumpAndSettle();

    expect(find.text('already-loaded'), findsWidgets);
    expect(find.textContaining('next page failed'), findsNothing);
  });
}

Widget _notificationTestApp({
  required NotificationController controller,
  ThemeData? theme,
}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            NotificationPage(controller: controller),
      ),
    ],
  );

  return AppLanguageScope(
    controller: AppLanguageController.instance,
    child: MaterialApp.router(theme: theme, routerConfig: router),
  );
}

NotificationController _controllerWithPages(
  List<NotificationPageResult> pages,
) {
  return NotificationController(
    inbox: NotificationInboxController(
      repository: _FakeNotificationRepository(pages),
    ),
  );
}

AppNotification _notification(String id) => AppNotification(
  id: id,
  type: AppNotificationType.account,
  icon: AppNotificationIcon.badge,
  title: id,
  description: 'description-$id',
  timestampLabel: 'now',
  target: const NotificationTarget(kind: NotificationTargetKind.upgradeAccount),
);

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.pages);

  final List<NotificationPageResult> pages;
  int _pageIndex = 0;

  @override
  Future<NotificationPageResult> fetchPage({
    int limit = 20,
    String? cursor,
  }) async => pages[_pageIndex++];

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

class _FailingLoadMoreNotificationRepository implements NotificationRepository {
  int _fetchCount = 0;

  @override
  Future<NotificationPageResult> fetchPage({
    int limit = 20,
    String? cursor,
  }) async {
    if (_fetchCount++ == 0) {
      return NotificationPageResult(
        items: <AppNotification>[_notification('already-loaded')],
        nextCursor: 'next-page',
      );
    }
    throw StateError('next page failed');
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
