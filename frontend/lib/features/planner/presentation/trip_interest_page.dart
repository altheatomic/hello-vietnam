import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_request.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class TripInterestPage extends StatefulWidget {
  const TripInterestPage({super.key, this.wizard});

  final TripWizardData? wizard;

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

    setState(() => _isLoading = true);

    try {
      final response = await TripRepository().planTrip(
        TripPlanRequest(
          idProvince: isBusinessTrip ? null : wizard?.idProvince,
          nDays: nDays,
          startDate: wizard?.startDate,
          savePlan: true,
          interestOptionIds: _selectedIds.toList(),
          targetLat: isBusinessTrip ? wizard?.targetLat : null,
          targetLng: isBusinessTrip ? wizard?.targetLng : null,
        ),
      );
      if (!mounted) return;
      final String? idPlan = response.idPlan?.trim();

      if (idPlan != null && idPlan.isNotEmpty) {
        context.push(AppRoutes.tripPlannerResultPath(idPlan: idPlan));
      } else {
        context.push(AppRoutes.tripPlannerResultPath(), extra: response);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Could not generate your trip. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return PlannerStepScaffold(
      currentStep: 4,
      badgeIcon: Icons.explore_outlined,
      title: 'What is your interest?',
      subtitle: 'Select your preferences (multiple choices)',
      onBack: () => context.pop(),
      nextEnabled: _selectedIds.isNotEmpty && !_isLoading,
      nextLabel: _isLoading ? 'Generating...' : 'Generate',
      onNext: _isLoading ? null : _generate,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: <Widget>[
            if (_isLoading) ...<Widget>[
              _LoadingBanner(),
              const SizedBox(height: 20),
            ],
            ..._options.map((_InterestOption option) {
              final bool selected = _selectedIds.contains(option.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InterestCard(
                  option: option,
                  selected: selected,
                  onTap: _isLoading ? null : () => _toggleOption(option.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB8E9FF)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.l10n.ui('Generating your personalised itinerary…'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B495D),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
            color: Colors.white.withValues(alpha: selected ? 0.98 : 0.95),
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
              Text(option.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.ui(option.title),
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22B7F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.ui(option.subtitle),
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF5F6B7C),
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
