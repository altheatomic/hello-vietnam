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

class TripInterestPage extends StatefulWidget {
  const TripInterestPage({super.key, this.wizard, this.generateTrip});

  final TripWizardData? wizard;
  final Future<TripPlanResponse> Function(TripPlanRequest request)?
  generateTrip;

  @override
  State<TripInterestPage> createState() => _TripInterestPageState();
}

class _TripInterestPageState extends State<TripInterestPage> {
  static const List<_InterestOption> _options = <_InterestOption>[
    _InterestOption(
      id: 'culture_history',
      emoji: '🏛️',
      title: 'Culture & History',
      subtitle: 'Museums, temples, heritage',
    ),
    _InterestOption(
      id: 'nature_outdoor',
      emoji: '🌿',
      title: 'Nature & Outdoor',
      subtitle: 'Hiking, beaches, parks',
    ),
    _InterestOption(
      id: 'adventure',
      emoji: '⛰️',
      title: 'Adventure',
      subtitle: 'Sports, thrills, exploration',
    ),
    _InterestOption(
      id: 'entertainment',
      emoji: '🎭',
      title: 'Entertainment',
      subtitle: 'Shopping, nightlife, events',
    ),
  ];

  final Set<String> _selectedIds = <String>{};
  bool _isLoading = false;
  bool _transitionFinished = false;
  TripPlanResponse? _pendingResponse;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant TripInterestPage oldWidget) {
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

  void _toggleOption(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _generate() async {
    if (_isLoading) return;

    final wizard = widget.wizard;
    final nDays = wizard?.nDays;
    final tripType = wizard?.tripType;
    final isBusinessTrip = tripType == 'business';

    // Validate: business trip needs lat/lng; leisure trip needs idProvince.
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
      if (wizard?.idProvince == null) {
        _showError('Missing destination. Please start from the beginning.');
        return;
      }
    }

    final request = TripPlanRequest(
      idProvince: isBusinessTrip ? null : wizard?.idProvince,
      nDays: nDays,
      startDate: wizard?.startDate,
      savePlan: true,
      interestOptionIds: _selectedIds.toList(),
      targetLat: isBusinessTrip ? wizard?.targetLat : null,
      targetLng: isBusinessTrip ? wizard?.targetLng : null,
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
      currentStep: 4,
      badgeIcon: Icons.explore_outlined,
      title: 'What is your interest?',
      subtitle: 'Select your preferences (multiple choices)',
      onBack: () => context.pop(),
      nextEnabled: _selectedIds.isNotEmpty,
      nextLabel: 'Generate',
      onNext: _generate,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: <Widget>[
            ..._options.map((_InterestOption option) {
              final bool selected = _selectedIds.contains(option.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InterestCard(
                  option: option,
                  selected: selected,
                  onTap: () => _toggleOption(option.id),
                ),
              );
            }),
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
      first.businessAddress == second.businessAddress;
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.option,
    required this.selected,
    this.onTap,
  });

  final _InterestOption option;
  final bool selected;
  final VoidCallback? onTap;

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
              Text(option.emoji, style: TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.ui(option.title),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22B7F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.ui(option.subtitle),
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
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

class _InterestOption {
  const _InterestOption({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String emoji;
  final String title;
  final String subtitle;
}
