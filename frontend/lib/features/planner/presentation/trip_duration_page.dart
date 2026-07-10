import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripDurationPage extends StatefulWidget {
  const TripDurationPage({super.key, this.wizard});

  final TripWizardData? wizard;

  @override
  State<TripDurationPage> createState() => _TripDurationPageState();
}

class _TripDurationPageState extends State<TripDurationPage> {
  DateTimeRange? _selectedRange;

  void _onNext() {
    final range = _selectedRange!;
    final startDate =
        '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final nDays = range.duration.inDays + 1;
    context.push(
      AppRoutes.tripPlannerInterest,
      extra: widget.wizard?.copyWith(startDate: startDate, nDays: nDays) ??
          TripWizardData(startDate: startDate, nDays: nDays),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 3,
      badgeIcon: Icons.calendar_today_outlined,
      title: "When's your trip?",
      subtitle: 'Choose your travel dates',
      onBack: () => context.pop(),
      nextEnabled: _selectedRange != null,
      onNext: _onNext,
      body: DateRangeCalendar(
        onRangeChanged: (DateTimeRange? range) =>
            setState(() => _selectedRange = range),
      ),
    );
  }
}
