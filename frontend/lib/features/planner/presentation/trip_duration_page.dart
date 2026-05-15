import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripDurationPage extends StatefulWidget {
  const TripDurationPage({super.key});

  @override
  State<TripDurationPage> createState() => _TripDurationPageState();
}

class _TripDurationPageState extends State<TripDurationPage> {
  static const List<String> _durations = <String>[
    '1 day (Day trip)',
    '2 days 1 night',
    '3 days 2 nights',
    '4 days 3 nights',
    '5 days 4 nights',
    'More than 5 days',
  ];

  String? _selectedDuration;

  void _showNextPlaceholder() {
    context.push(AppRoutes.tripPlannerInterest);
  }

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 3,
      badgeIcon: Icons.calendar_today_outlined,
      title: 'How long will you stay?',
      subtitle: 'Choose your trip duration',
      onBack: () => context.pop(),
      nextEnabled: _selectedDuration != null,
      onNext: _showNextPlaceholder,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: _durations.map((String duration) {
            final bool selected = duration == _selectedDuration;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DurationCard(
                label: duration,
                selected: selected,
                onTap: () {
                  setState(() {
                    _selectedDuration = duration;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.98 : 0.95),
            borderRadius: BorderRadius.circular(18),
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
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF22B7F1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
