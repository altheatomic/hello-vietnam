import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripInterestPage extends StatefulWidget {
  const TripInterestPage({super.key});

  @override
  State<TripInterestPage> createState() => _TripInterestPageState();
}

class _TripInterestPageState extends State<TripInterestPage> {
  static const List<_InterestOption> _options = <_InterestOption>[
    _InterestOption(
      id: 'culture',
      emoji: '🏛️',
      title: 'Culture & History',
      subtitle: 'Museums, temples, heritage',
    ),
    _InterestOption(
      id: 'nature',
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

  final Set<String> _selectedIds = <String>{'entertainment'};

  void _toggleOption(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showNextPlaceholder() {
    context.push(AppRoutes.tripPlannerBudget);
  }

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 4,
      badgeIcon: Icons.explore_outlined,
      title: 'What is your interest?',
      subtitle: 'Select your preferences (multiple choices)',
      onBack: () => context.pop(),
      nextEnabled: _selectedIds.isNotEmpty,
      onNext: _showNextPlaceholder,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: _options.map((_InterestOption option) {
            final bool selected = _selectedIds.contains(option.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _InterestCard(
                option: option,
                selected: selected,
                onTap: () => _toggleOption(option.id),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _InterestOption option;
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
                      option.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22B7F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.subtitle,
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
