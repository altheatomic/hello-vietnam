import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripDurationPage extends StatefulWidget {
  const TripDurationPage({super.key});

  @override
  State<TripDurationPage> createState() => _TripDurationPageState();
}

class _TripDurationPageState extends State<TripDurationPage> {
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 3,
      badgeIcon: Icons.calendar_today_outlined,
      title: context.l10n.ui("When's your trip?"),
      subtitle: context.l10n.ui('Choose your travel dates'),
      onBack: () => context.pop(),
      nextEnabled: _selectedRange != null,
      onNext: () => context.push(AppRoutes.tripPlannerInterest),
      body: DateRangeCalendar(
        onRangeChanged: (DateTimeRange? range) =>
            setState(() => _selectedRange = range),
      ),
    );
  }
}
