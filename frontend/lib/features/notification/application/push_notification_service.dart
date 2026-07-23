import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import 'notification_inbox_controller.dart';
import 'push_notification_tap_controller.dart';

enum PushAuthorizationStatus { authorized, provisional, denied, notDetermined }

class PushNotificationMessage {
  const PushNotificationMessage({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.data,
  });

  final String? notificationId;
  final String? title;
  final String? body;
  final Map<String, String> data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'notificationId': notificationId,
    'title': title,
    'body': body,
    'data': data,
  };

  factory PushNotificationMessage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final Map<String, String> data = <String, String>{};
    if (rawData is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawData.entries) {
        data[entry.key.toString()] = entry.value.toString();
      }
    }
    return PushNotificationMessage(
      notificationId: json['notificationId']?.toString(),
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      data: data,
    );
  }

  AppNotification toAppNotification() {
    Map<String, dynamic> target = <String, dynamic>{};
    final String? rawTarget = data['target'];
    if (rawTarget != null && rawTarget.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(rawTarget);
        if (decoded is Map) {
          target = decoded.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          );
        }
      } on FormatException {
        target = <String, dynamic>{};
      }
    }

    return AppNotification.fromJson(<String, dynamic>{
      'id_notification':
          data['id_notification'] ?? notificationId ?? 'push-notification',
      'notification_type': data['notification_type'] ?? 'account',
      'title': title ?? '',
      'body': body ?? '',
      'payload_jsonb': <String, dynamic>{'target': target},
    });
  }
}

abstract interface class PushMessagingGateway {
  Future<void> initialize();
  Future<PushAuthorizationStatus> requestPermission();
  Future<String?> getToken();
  Future<PushNotificationMessage?> getInitialMessage();
  Stream<String> get tokenRefreshes;
  Stream<PushNotificationMessage> get foregroundMessages;
  Stream<PushNotificationMessage> get openedMessages;
}

abstract interface class LocalNotificationGateway {
  Future<void> initialize(
    Future<void> Function(PushNotificationMessage message) onTap,
  );
  Future<void> show(PushNotificationMessage message);
}

abstract interface class InstallationIdProvider {
  Future<String> getOrCreate();
}

class PushNotificationService {
  PushNotificationService({
    required PushMessagingGateway messaging,
    required LocalNotificationGateway localNotifications,
    required NotificationRepository repository,
    required InstallationIdProvider installationIdProvider,
    required String? Function() currentUserId,
    required bool isSupportedPlatform,
    VoidCallback? onNotificationReceived,
    Future<void> Function(PushNotificationMessage message)?
    onNotificationTapped,
  }) : _messaging = messaging,
       _localNotifications = localNotifications,
       _repository = repository,
       _installationIdProvider = installationIdProvider,
       _currentUserId = currentUserId,
       _isSupportedPlatform = isSupportedPlatform,
       _onNotificationReceived = onNotificationReceived,
       _onNotificationTapped = onNotificationTapped;

  static final PushNotificationService instance = PushNotificationService(
    messaging: FirebasePushMessagingGateway(),
    localNotifications: FlutterLocalNotificationGateway(),
    repository: SupabaseNotificationRepository.instance,
    installationIdProvider: SharedPreferencesInstallationIdProvider(),
    currentUserId: () => Supabase.instance.client.auth.currentUser?.id,
    isSupportedPlatform:
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    onNotificationReceived: () {
      NotificationInboxController.instance.notifyPushReceived();
      unawaited(NotificationInboxController.instance.refresh());
    },
    onNotificationTapped: PushNotificationTapController.instance.enqueue,
  );

  final PushMessagingGateway _messaging;
  final LocalNotificationGateway _localNotifications;
  final NotificationRepository _repository;
  final InstallationIdProvider _installationIdProvider;
  final String? Function() _currentUserId;
  final bool _isSupportedPlatform;
  final VoidCallback? _onNotificationReceived;
  final Future<void> Function(PushNotificationMessage message)?
  _onNotificationTapped;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) return;
    _initialized = true;

    try {
      await _messaging.initialize();
      await _localNotifications.initialize(_handleNotificationTap);
      _subscriptions
        ..add(
          _messaging.tokenRefreshes.listen(
            (String token) => unawaited(_registerTokenSafely(token)),
          ),
        )
        ..add(
          _messaging.foregroundMessages.listen(
            (PushNotificationMessage message) =>
                unawaited(_handleForegroundMessageSafely(message)),
          ),
        )
        ..add(
          _messaging.openedMessages.listen(
            (PushNotificationMessage message) =>
                unawaited(_handleNotificationTapSafely(message)),
          ),
        );

      final PushNotificationMessage? initialMessage = await _messaging
          .getInitialMessage();
      if (initialMessage != null) {
        await _handleNotificationTap(initialMessage);
      }
      await syncCurrentDevice();
    } catch (_) {
      _initialized = false;
      rethrow;
    }
  }

  Future<bool> syncCurrentDevice() async {
    if (!_initialized || !_isSupportedPlatform || _currentUserId() == null) {
      return false;
    }
    final PushAuthorizationStatus status = await _messaging.requestPermission();
    if (status != PushAuthorizationStatus.authorized &&
        status != PushAuthorizationStatus.provisional) {
      return false;
    }
    final String? token = await _messaging.getToken();
    if (token == null || token.isEmpty) return false;
    await _registerToken(token);
    return true;
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_isSupportedPlatform || _currentUserId() == null) return;
    final String installationId = await _installationIdProvider.getOrCreate();
    await _repository.unregisterDevice(installationId);
  }

  Future<void> _registerToken(String token) async {
    if (_currentUserId() == null || token.isEmpty) return;
    final String installationId = await _installationIdProvider.getOrCreate();
    await _repository.registerDevice(
      fcmToken: token,
      installationId: installationId,
      platform: 'android',
    );
  }

  Future<void> _handleForegroundMessage(PushNotificationMessage message) async {
    _onNotificationReceived?.call();
    await _localNotifications.show(message);
  }

  Future<void> _handleForegroundMessageSafely(
    PushNotificationMessage message,
  ) async {
    try {
      await _handleForegroundMessage(message);
    } catch (error) {
      debugPrint('Foreground push handling failed: $error');
    }
  }

  Future<void> _handleNotificationTap(PushNotificationMessage message) async {
    await _onNotificationTapped?.call(message);
  }

  Future<void> _handleNotificationTapSafely(
    PushNotificationMessage message,
  ) async {
    try {
      await _handleNotificationTap(message);
    } catch (error) {
      debugPrint('Push notification tap handling failed: $error');
    }
  }

  Future<void> _registerTokenSafely(String token) async {
    try {
      await _registerToken(token);
    } catch (error) {
      debugPrint('FCM token refresh registration failed: $error');
    }
  }

  Future<void> dispose() async {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  @override
  Stream<PushNotificationMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_fromRemoteMessage);

  @override
  Stream<PushNotificationMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_fromRemoteMessage);

  @override
  Stream<String> get tokenRefreshes =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Future<PushNotificationMessage?> getInitialMessage() async {
    final RemoteMessage? message = await FirebaseMessaging.instance
        .getInitialMessage();
    return message == null ? null : _fromRemoteMessage(message);
  }

  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return PushAuthorizationStatus.authorized;
      case AuthorizationStatus.provisional:
        return PushAuthorizationStatus.provisional;
      case AuthorizationStatus.denied:
        return PushAuthorizationStatus.denied;
      case AuthorizationStatus.notDetermined:
        return PushAuthorizationStatus.notDetermined;
    }
  }

  static PushNotificationMessage _fromRemoteMessage(RemoteMessage message) {
    return PushNotificationMessage(
      notificationId: message.data['id_notification'] ?? message.messageId,
      title: message.notification?.title ?? message.data['title'],
      body: message.notification?.body ?? message.data['body'],
      data: message.data.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'hello_vietnam_updates',
    'Hello Vietnam updates',
    description: 'Trip, forum, loyalty, voucher and account updates.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize(
    Future<void> Function(PushNotificationMessage message) onTap,
  ) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final dynamic decoded = jsonDecode(payload);
        if (decoded is Map) {
          await onTap(
            PushNotificationMessage.fromJson(
              decoded.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          );
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  @override
  Future<void> show(PushNotificationMessage message) async {
    await _plugin.show(
      id: _notificationId(message),
      title: message.title,
      body: message.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.toJson()),
    );
  }

  int _notificationId(PushNotificationMessage message) {
    final String seed =
        message.notificationId ??
        '${message.title}|${message.body}|${DateTime.now().microsecondsSinceEpoch}';
    return seed.hashCode & 0x7fffffff;
  }
}

class SharedPreferencesInstallationIdProvider
    implements InstallationIdProvider {
  static const String _key = 'push_installation_id';

  @override
  Future<String> getOrCreate() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? existing = preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final Random random = Random.secure();
    final String value = <int>[
      DateTime.now().microsecondsSinceEpoch,
      random.nextInt(1 << 32),
      random.nextInt(1 << 32),
    ].map((int part) => part.toRadixString(16)).join('-');
    await preferences.setString(_key, value);
    return value;
  }
}
