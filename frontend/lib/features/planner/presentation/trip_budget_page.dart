import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_request.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

/// Step 5 — "Có nghỉ trưa không?" (replaces the former budget step, whose
/// picks were never actually sent to the backend — see
/// docs/superpowers/... lunch-break audit). Still the final wizard step and
/// still owns the "Generate" action.
class TripBudgetPage extends StatefulWidget {
  const TripBudgetPage({super.key, this.wizard, this.generateTrip});

  final TripWizardData? wizard;
  final Future<TripPlanResponse> Function(TripPlanRequest request)?
  generateTrip;

  @override
  State<TripBudgetPage> createState() => _TripBudgetPageState();
}

class _TripBudgetPageState extends State<TripBudgetPage> {
  // Defaults to true (include a lunch break) so the page opens already
  // selected — matches TripWizardData's default and requires no forced
  // choice before Generate is enabled.
  bool _includeLunchBreak = true;
  bool _isLoading = false;
  bool _transitionFinished = false;
  TripPlanResponse? _pendingResponse;
  int _generation = 0;

  bool get _canGenerate => !_isLoading;

  @override
  void initState() {
    super.initState();
    _includeLunchBreak = widget.wizard?.includeLunchBreak ?? true;
  }

  @override
  void didUpdateWidget(covariant TripBudgetPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameWizardData(oldWidget.wizard, widget.wizard) && _isLoading) {
      _generation++;
      _isLoading = false;
      _transitionFinished = false;
      _pendingResponse = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  void _selectIncludeLunchBreak(bool value) {
    setState(() {
      _includeLunchBreak = value;
    });
  }

  Future<void> _generate() async {
    if (_isLoading) return;

    final wizard = widget.wizard;
    final idProvince = wizard?.idProvince;
    final nDays = wizard?.nDays;
    final tripType = wizard?.tripType;
    final isBusinessTrip = tripType == 'business';

    if (nDays == null) {
      _showError('Missing trip details. Please start from the beginning.');
      return;
    }
    if (isBusinessTrip) {
      if (wizard?.targetLat == null || wizard?.targetLng == null) {
        _showError(
          'Missing business location. Please go back and enter an address.',
        );
        return;
      }
    } else {
      if (idProvince == null) {
        _showError('Missing trip details. Please start from the beginning.');
        return;
      }
    }

    final request = TripPlanRequest(
      idProvince: isBusinessTrip ? null : idProvince,
      nDays: nDays,
      startDate: wizard?.startDate,
      targetLat: isBusinessTrip ? wizard?.targetLat : null,
      targetLng: isBusinessTrip ? wizard?.targetLng : null,
      includeLunchBreak: _includeLunchBreak,
      // Carried forward from Step 4 (Interest) via TripWizardData — Interest
      // page no longer builds the request itself, it just navigates here.
      interestOptionIds: wizard?.interestOptionIds,
    );
    final int generation = ++_generation;
    setState(() {
      _isLoading = true;
      _transitionFinished = false;
      _pendingResponse = null;
    });

    try {
      final response =
          await (widget.generateTrip?.call(request) ??
              TripRepository().planTrip(request));
      if (!mounted || generation != _generation) return;
      setState(() => _pendingResponse = response);
    } on NoTripCandidatesException {
      if (!mounted) return;
      _failGeneration(
        generation,
        'Not enough places found for your selection. Try selecting more '
        'interests (step 4) or fewer days (step 3).',
      );
    } on SupabaseFunctionException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'no_candidates') {
        _failGeneration(
          generation,
          'Not enough places found for your selection. Try selecting more '
          'interests (step 4) or fewer days (step 3).',
        );
      } else if (e.errorCode == 'timeout') {
        // The client gave up waiting, but Future.timeout() never cancelled
        // the actual request — the backend may well have finished and
        // saved the plan anyway (this is the exact race that produced
        // duplicate trips before: user sees an error, taps Generate again,
        // gets a second identical plan). Check for a plan matching this
        // request created in just the last few minutes before showing any
        // error — if found, treat it exactly like a normal success.
        await _recoverFromTimeoutOrFail(generation, request);
      } else {
        _failGeneration(
          generation,
          'Could not generate your trip. Please try again.',
        );
      }
    } catch (e) {
      _failGeneration(
        generation,
        'Could not generate your trip. Please try again.',
      );
    }
  }

  /// Checks whether a plan matching [request] was actually created by the
  /// backend despite the client timing out — see the errorCode == 'timeout'
  /// branch in _generate(). Finding one is treated exactly like a normal
  /// successful response (navigates to the result page); finding nothing
  /// falls back to the same generic error a real failure would show.
  Future<void> _recoverFromTimeoutOrFail(
    int generation,
    TripPlanRequest request,
  ) async {
    try {
      final recent = await TripRepository().findRecentMatchingPlan(request);
      if (!mounted || generation != _generation) return;
      if (recent != null) {
        final TripPlanResponse fullResponse = await TripRepository().getPlan(
          recent.idPlan,
        );
        if (!mounted || generation != _generation) return;
        setState(() => _pendingResponse = fullResponse);
        return;
      }
    } catch (_) {
      // Recovery check itself failed (e.g. listPlans/getPlan errored) —
      // fall through to the generic error below rather than leaving the
      // user stuck on the loading screen.
    }
    _failGeneration(
      generation,
      'Could not generate your trip. Please try again.',
    );
  }

  void _failGeneration(int generation, String message) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _isLoading = false;
      _transitionFinished = false;
      _pendingResponse = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || _isLoading) return;
      _showError(message);
    });
  }

  void _finishGenerationTransition() {
    final response = _pendingResponse;
    if (!mounted || !_isLoading || response == null || _transitionFinished) {
      return;
    }

    _transitionFinished = true;
    setState(() {
      _isLoading = false;
      _pendingResponse = null;
    });

    final String? idPlan = response.idPlan?.trim();
    if (idPlan != null && idPlan.isNotEmpty) {
      context.push(
        AppRoutes.tripPlannerResultPath(idPlan: idPlan),
        extra: response,
      );
    } else {
      context.push(AppRoutes.tripPlannerResultPath(), extra: response);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.ui(message)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return VietnamJourneyLoadingScreen(
        message: context.l10n.ui('Generating your personalised itinerary…'),
        isComplete: _pendingResponse != null,
        onExitComplete: _finishGenerationTransition,
      );
    }

    return PlannerStepScaffold(
      currentStep: 5,
      badgeIcon: Icons.free_breakfast_outlined,
      title: 'Do you want a lunch break?',
      subtitle: 'Choose one option below to continue',
      onBack: () => context.pop(),
      nextEnabled: _canGenerate,
      nextLabel: 'Generate',
      onNext: _generate,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.ui(
                'We can reserve a 90-minute midday break and suggest nearby '
                'restaurants, or skip it and keep exploring instead.',
              ),
              style: TextStyle(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            _LunchBreakOptionCard(
              icon: Icons.restaurant_outlined,
              title: context.l10n.ui('Yes, reserve lunch time'),
              subtitle: context.l10n.ui(
                'Keep a midday break and see restaurant suggestions nearby.',
              ),
              selected: _includeLunchBreak,
              onTap: () => _selectIncludeLunchBreak(true),
            ),
            const SizedBox(height: 14),
            _LunchBreakOptionCard(
              icon: Icons.directions_walk_outlined,
              title: context.l10n.ui('No, keep exploring'),
              subtitle: context.l10n.ui(
                'Skip the midday break so the day can fit more activities '
                'or end earlier.',
              ),
              selected: !_includeLunchBreak,
              onTap: () => _selectIncludeLunchBreak(false),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameWizardData(TripWizardData? first, TripWizardData? second) {
  if (identical(first, second)) return true;
  if (first == null || second == null) return false;
  return first.idProvince == second.idProvince &&
      first.provinceName == second.provinceName &&
      first.startDate == second.startDate &&
      first.nDays == second.nDays &&
      first.tripType == second.tripType &&
      first.targetLat == second.targetLat &&
      first.targetLng == second.targetLng &&
      first.businessAddress == second.businessAddress &&
      first.includeLunchBreak == second.includeLunchBreak;
}

class _LunchBreakOptionCard extends StatelessWidget {
  const _LunchBreakOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: selected ? 0.98 : 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF22B7F1)
                  : const Color(0xFFC4F4FF),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: selected
                    ? const Color(0x2222B7F1)
                    : const Color(0x260F2C4F),
                blurRadius: selected ? 24 : 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 30, color: const Color(0xFF22B7F1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22B7F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22B7F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
