import 'dart:async';

import 'package:flutter/foundation.dart';

import 'push_notification_service.dart';

class PushNotificationTapController extends ChangeNotifier {
  PushNotificationTapController._();

  static final PushNotificationTapController instance =
      PushNotificationTapController._();

  PushNotificationMessage? _pending;

  PushNotificationMessage? takePending() {
    final PushNotificationMessage? value = _pending;
    _pending = null;
    return value;
  }

  Future<void> enqueue(PushNotificationMessage message) async {
    _pending = message;
    notifyListeners();
  }
}
