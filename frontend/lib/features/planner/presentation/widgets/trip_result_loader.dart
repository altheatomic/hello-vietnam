import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/presentation/trip_result_page.dart';

class TripResultLoader extends StatefulWidget {
  const TripResultLoader({
    super.key,
    required this.idPlan,
    required this.draft,
  });

  final String? idPlan;
  final TripPlanResponse? draft;

  @override
  State<TripResultLoader> createState() => _TripResultLoaderState();
}

class _TripResultLoaderState extends State<TripResultLoader> {
  TripPlanResponse? _plan;
  Object? _error;
  bool _isLoading = false;

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
    final String? idPlan = _normalizedIdPlan;
    if (idPlan == null) {
      setState(() {
        _plan = widget.draft;
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _plan = null;
      _error = null;
      _isLoading = true;
    });

    try {
      final TripPlanResponse plan = await TripRepository().getPlan(idPlan);
      if (!mounted || idPlan != _normalizedIdPlan) return;
      setState(() {
        _plan = plan;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || idPlan != _normalizedIdPlan) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.tripPlanner);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _TripResultMessageView(
        message: 'Could not load trip. Please try again.',
        buttonLabel: 'Go back',
        onPressed: _goBack,
      );
    }

    final TripPlanResponse? plan = _plan;
    if (plan != null) {
      return TripResultPage(plan: plan);
    }

    return _TripResultMessageView(
      message:
          'This trip is no longer available. Please generate it again.',
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
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
