import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/notification/application/push_notification_service.dart';
import '../features/notification/application/push_notification_tap_controller.dart';
import '../features/notification/presentation/notification_action_handler.dart';
import 'app.dart';
import 'router.dart';

class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter();
    PushNotificationTapController.instance.addListener(_handlePushTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePushTap());
  }

  void _handlePushTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? context = rootNavigatorKey.currentContext;
      if (context == null) return;
      final PushNotificationMessage? message = PushNotificationTapController
          .instance
          .takePending();
      if (message == null) return;
      NotificationActionHandler.open(context, message.toAppNotification());
    });
  }

  @override
  void dispose() {
    PushNotificationTapController.instance.removeListener(_handlePushTap);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return App(router: _router);
  }
}
