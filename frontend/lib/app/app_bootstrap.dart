import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/data/reference_data_cache_repository.dart';
import '../core/language/app_language.dart';
import '../core/storage/local_storage.dart' as app_storage;
import '../core/widgets/app_loading_screen.dart';
import '../core/widgets/journey_loading/journey_loading_timeline.dart';
import '../features/forum/data/forum_store.dart';
import '../features/notification/application/notification_inbox_controller.dart';
import '../features/notification/application/push_notification_service.dart';
import '../features/personalization/data/travel_preferences_repository.dart';
import '../features/planner/data/trip_store.dart';
import '../features/profile/application/premium_entitlement_controller.dart';
import 'app_mobile.dart';
import 'deep_link_state.dart';
import 'theme.dart';
import 'theme_controller.dart';

typedef AppInitializer = Future<void> Function();

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.initializeApp,
    this.readyBuilder,
    this.timelineFactory,
  });

  final AppInitializer? initializeApp;
  final WidgetBuilder? readyBuilder;
  final JourneyLoadingTimeline Function()? timelineFactory;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  Object? _error;
  bool _dataReady = false;
  bool _animationExited = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await (widget.initializeApp ?? _initializeProductionApp)();

      if (!mounted) return;
      setState(() => _dataReady = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _dataReady = false;
        _animationExited = false;
      });
    }
  }

  Future<void> _initializeProductionApp() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );

    await app_storage.LocalStorage.instance.initialize();
    await AppLanguageController.instance.initialize();
    await ThemeController.instance.initialize();
    PremiumEntitlementController.instance.initialize();
    await TravelPreferencesRepository.instance.initialize();
    await ReferenceDataCacheRepository.instance.initialize();
    await TripStore.instance.init();
    await ForumStore.instance.init(preload: false);
    await initDeepLinks();
    await ReferenceDataCacheRepository.instance.refreshStaleInBackground();
    try {
      await PushNotificationService.instance.initialize();
    } catch (error) {
      debugPrint('Push notification initialization skipped: $error');
    }
    if (Supabase.instance.client.auth.currentUser != null) {
      try {
        await NotificationInboxController.instance.loadInitial();
      } catch (error) {
        debugPrint('Notification inbox preload skipped: $error');
      }
    }
  }

  void _handleExitComplete() {
    if (!mounted || !_dataReady || _error != null || _animationExited) {
      return;
    }
    setState(() => _animationExited = true);
  }

  void _retry() {
    setState(() {
      _error = null;
      _dataReady = false;
      _animationExited = false;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_dataReady && _animationExited) {
      return widget.readyBuilder?.call(context) ?? const MobileApp();
    }

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeController.instance.themeMode,
          home: _error == null
              ? AppLoadingScreen(
                  message: 'Opening Hello Vietnam',
                  isComplete: _dataReady,
                  onExitComplete: _handleExitComplete,
                  timelineFactory: widget.timelineFactory,
                )
              : _BootstrapError(error: _error!, onRetry: _retry),
        );
      },
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 14),
              const Text(
                'Unable to start the app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
