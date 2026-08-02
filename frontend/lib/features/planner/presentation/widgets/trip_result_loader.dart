import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/journey_loading/journey_loading_timeline.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/presentation/trip_result_page.dart';

typedef TripPlanLoader = Future<TripPlanResponse> Function(String idPlan);

class TripResultLoader extends StatefulWidget {
  const TripResultLoader({
    super.key,
    required this.idPlan,
    required this.draft,
    this.returnToNotification = false,
    this.loadPlan,
    this.timelineFactory,
  });

  final String? idPlan;
  final TripPlanResponse? draft;
  final bool returnToNotification;
  final TripPlanLoader? loadPlan;
  final JourneyLoadingTimeline Function()? timelineFactory;

  @override
  State<TripResultLoader> createState() => _TripResultLoaderState();
}

class _TripResultLoaderState extends State<TripResultLoader> {
  TripPlanResponse? _loadedPlan;
  Object? _error;
  bool _showResult = false;
  int _loadGeneration = 0;

  String? get _normalizedIdPlan {
    final String value = widget.idPlan?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TripResultLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idPlan != widget.idPlan || oldWidget.draft != widget.draft) {
      _load();
    }
  }

  Future<void> _load() async {
    final int loadGeneration = ++_loadGeneration;
    final String? idPlan = _normalizedIdPlan;
    if (idPlan == null) {
      setState(() {
        _loadedPlan = widget.draft;
        _error = null;
        _showResult = widget.draft != null;
      });
      return;
    }

    setState(() {
      _loadedPlan = null;
      _error = null;
      _showResult = false;
    });

    try {
      final TripPlanResponse plan =
          await (widget.loadPlan?.call(idPlan) ??
              TripRepository().getPlan(idPlan));
      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() {
        _loadedPlan = plan;
      });
    } catch (error) {
      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() {
        _error = error;
        _loadedPlan = null;
        _showResult = false;
      });
    }
  }

  void _handleExitComplete() {
    if (!mounted || _error != null || _loadedPlan == null || _showResult) {
      return;
    }
    setState(() => _showResult = true);
  }

  void _goBack() {
    if (widget.returnToNotification) {
      context.go(AppRoutes.notification);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.tripPlanner);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _TripResultMessageView(
        message: 'Could not load trip. Please try again.',
        buttonLabel: 'Go back',
        onPressed: _goBack,
      );
    }

    final TripPlanResponse? plan = _loadedPlan;
    if (_showResult && plan != null) {
      return PopScope<void>(
        canPop: !widget.returnToNotification,
        onPopInvokedWithResult: (bool didPop, void result) {
          if (!didPop && widget.returnToNotification) {
            context.go(AppRoutes.notification);
          }
        },
        child: TripResultPage(
          plan: plan,
          onBack: widget.returnToNotification ? _goBack : null,
        ),
      );
    }

    if (_normalizedIdPlan != null) {
      return VietnamJourneyLoadingScreen(
        key: ValueKey<int>(_loadGeneration),
        message: context.l10n.ui('Preparing your Vietnam journey'),
        isComplete: plan != null,
        onExitComplete: _handleExitComplete,
        timelineFactory: widget.timelineFactory,
      );
    }

    return _TripResultMessageView(
      message: 'This trip is no longer available. Please generate it again.',
      buttonLabel: 'Back to trip planner',
      onPressed: () => context.go(AppRoutes.tripPlanner),
    );
  }
}

class _TripResultMessageView extends StatelessWidget {
  const _TripResultMessageView({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.luggage_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.ui(message),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(context.l10n.ui(buttonLabel)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
