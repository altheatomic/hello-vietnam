import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/subscription_repository.dart';

enum PremiumEntitlementStatus { loading, active, inactive, error }

@immutable
class PremiumEntitlementState {
  const PremiumEntitlementState({
    required this.status,
    this.subscription,
    this.error,
    this.userId,
    this.lastCheckedAt,
  });

  const PremiumEntitlementState.loading({String? userId})
    : this(status: PremiumEntitlementStatus.loading, userId: userId);

  final PremiumEntitlementStatus status;
  final CurrentSubscriptionInfo? subscription;
  final Object? error;
  final String? userId;
  final DateTime? lastCheckedAt;

  bool get isActive => status == PremiumEntitlementStatus.active;
  bool get isConfirmedInactive => status == PremiumEntitlementStatus.inactive;
}

typedef PremiumSubscriptionLoader = Future<CurrentSubscriptionInfo?> Function();
typedef PremiumCurrentUserId = String? Function();
typedef PremiumClock = DateTime Function();

class PremiumEntitlementController extends ChangeNotifier
    with WidgetsBindingObserver {
  PremiumEntitlementController({
    PremiumSubscriptionLoader? loadSubscription,
    PremiumCurrentUserId? currentUserId,
    Stream<String?>? authUserIds,
    PremiumClock? now,
  }) : _loadSubscription =
           loadSubscription ??
           (() => SubscriptionRepository().loadCurrentSubscription()),
       _currentUserId =
           currentUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id),
       _authUserIds =
           authUserIds ??
           (currentUserId == null ? null : const Stream<String?>.empty()),
       _now = now ?? DateTime.now;

  static final PremiumEntitlementController instance =
      PremiumEntitlementController();

  final PremiumSubscriptionLoader _loadSubscription;
  final PremiumCurrentUserId _currentUserId;
  final Stream<String?>? _authUserIds;
  final PremiumClock _now;

  PremiumEntitlementState _state = const PremiumEntitlementState.loading();
  Future<void>? _inFlight;
  String? _inFlightUserId;
  int _generation = 0;
  bool _initialized = false;
  bool _disposed = false;
  StreamSubscription<String?>? _authSubscription;

  PremiumEntitlementState get state => _state;

  bool get canUsePremium {
    final DateTime? endDate = _state.subscription?.endDate;
    return _state.status == PremiumEntitlementStatus.active &&
        endDate != null &&
        endDate.isAfter(_now().toUtc());
  }

  void initialize() {
    if (_initialized || _disposed) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final Stream<String?> stream =
        _authUserIds ??
        Supabase.instance.client.auth.onAuthStateChange.map(
          (AuthState event) => event.session?.user.id,
        );
    _authSubscription = stream.listen(_handleAuthUserChanged);
    unawaited(refresh());
  }

  Future<void> retry() => refresh(force: true);

  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future<void>.value();

    final String? userId = _currentUserId();
    if (userId == null) {
      _setSignedOut();
      return Future<void>.value();
    }

    if (!force && _inFlight != null && _inFlightUserId == userId) {
      return _inFlight!;
    }

    final int requestGeneration = ++_generation;
    _inFlightUserId = userId;
    if (_state.userId != userId ||
        _state.status == PremiumEntitlementStatus.error) {
      _publish(PremiumEntitlementState.loading(userId: userId));
    }
    _debugLog(
      'refresh start user=${_redactedUserId(userId)} '
      'generation=$requestGeneration force=$force',
    );

    final Future<void> request = _performRefresh(
      userId: userId,
      requestGeneration: requestGeneration,
    );
    _inFlight = request;
    unawaited(
      request.then((_) {
        if (identical(_inFlight, request)) {
          _inFlight = null;
          _inFlightUserId = null;
        }
      }),
    );
    return request;
  }

  Future<void> _performRefresh({
    required String userId,
    required int requestGeneration,
  }) async {
    try {
      final CurrentSubscriptionInfo? subscription = await _loadSubscription();
      if (!_ownsResult(userId, requestGeneration)) return;

      if (subscription == null) {
        _publish(
          PremiumEntitlementState(
            status: PremiumEntitlementStatus.inactive,
            userId: userId,
            lastCheckedAt: _now().toUtc(),
          ),
        );
        _debugResult(userId, requestGeneration, 'inactive');
        return;
      }

      _publish(
        PremiumEntitlementState(
          status: PremiumEntitlementStatus.active,
          subscription: subscription,
          userId: userId,
          lastCheckedAt: _now().toUtc(),
        ),
      );
      _debugResult(userId, requestGeneration, 'active');
    } catch (error) {
      if (!_ownsResult(userId, requestGeneration)) return;

      final CurrentSubscriptionInfo? lastSubscription = _state.userId == userId
          ? _state.subscription
          : null;
      final DateTime? endDate = lastSubscription?.endDate;
      final bool retainActive =
          _state.status == PremiumEntitlementStatus.active &&
          endDate != null &&
          endDate.isAfter(_now().toUtc());

      _publish(
        PremiumEntitlementState(
          status: retainActive
              ? PremiumEntitlementStatus.active
              : PremiumEntitlementStatus.error,
          subscription: lastSubscription,
          error: error,
          userId: userId,
          lastCheckedAt: _state.userId == userId ? _state.lastCheckedAt : null,
        ),
      );
      _debugResult(userId, requestGeneration, 'error', error: error);
    }
  }

  bool _ownsResult(String userId, int requestGeneration) {
    return !_disposed &&
        requestGeneration == _generation &&
        userId == _currentUserId();
  }

  void _handleAuthUserChanged(String? userId) {
    if (userId == null) {
      _setSignedOut();
      return;
    }
    unawaited(refresh(force: true));
  }

  void _setSignedOut() {
    ++_generation;
    _inFlight = null;
    _inFlightUserId = null;
    _publish(
      const PremiumEntitlementState(status: PremiumEntitlementStatus.inactive),
    );
  }

  void _publish(PremiumEntitlementState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh(force: true));
    }
  }

  void _debugResult(
    String userId,
    int generation,
    String result, {
    Object? error,
  }) {
    _debugLog(
      'refresh result user=${_redactedUserId(userId)} '
      'generation=$generation result=$result'
      '${error == null ? '' : ' error=$error'}',
    );
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('PremiumEntitlement: $message');
    }
  }

  String _redactedUserId(String userId) {
    if (userId.length <= 4) return '***';
    return '***${userId.substring(userId.length - 4)}';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
