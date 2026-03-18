import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// Recommendation 2.1 / 2.2 — date-range calendar picker.
///
/// • Scrollable list of month grids for the selected year.
/// • Tap once to set start date, tap again to set end date.
/// • Selected range highlighted with AppColors.primary.
/// • "Next" button activates only when a valid range is selected.
class RecommendWhenCalendarPage extends StatefulWidget {
  const RecommendWhenCalendarPage({super.key});

  @override
  State<RecommendWhenCalendarPage> createState() =>
      _RecommendWhenCalendarPageState();
}

class _RecommendWhenCalendarPageState
    extends State<RecommendWhenCalendarPage> {
  int _year = DateTime.now().year;
  DateTime? _start;
  DateTime? _end;

  bool get _hasRange => _start != null && _end != null;

  void _onDayTap(DateTime day) {
    setState(() {
      // First tap or reset: set start only
      if (_start == null || _hasRange) {
        _start = day;
        _end = null;
      } else {
        // Second tap: set end (swap if needed)
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
      }
    });
  }

  bool _isStart(DateTime d) =>
      _start != null &&
      d.year == _start!.year &&
      d.month == _start!.month &&
      d.day == _start!.day;

  bool _isEnd(DateTime d) =>
      _end != null &&
      d.year == _end!.year &&
      d.month == _end!.month &&
      d.day == _end!.day;

  bool _isInRange(DateTime d) {
    if (_start == null || _end == null) return false;
    return d.isAfter(_start!) && d.isBefore(_end!);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              statusBarHeight + 8,
              AppConstants.pagePadding,
              16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Expanded(
                  child: Text(
                    "When's your trip?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Spacer to visually balance the back arrow
                const SizedBox(width: 20),
              ],
            ),
          ),

          // ── Year navigator ────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.pagePadding,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius:
                  BorderRadius.circular(AppConstants.cardRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _year--),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _year++),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Month list ────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.pagePadding,
                vertical: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, i) => _MonthGrid(
                year: _year,
                month: i + 1,
                onDayTap: _onDayTap,
                isStart: _isStart,
                isEnd: _isEnd,
                isInRange: _isInRange,
              ),
            ),
          ),

          // ── Next button ───────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                8,
                AppConstants.pagePadding,
                16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _hasRange
                      ? () => context.push(
                            AppRoutes.recommendWhenResults,
                            extra: DateTimeRange(
                              start: _start!,
                              end: _end!,
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardRadius,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month grid widget ────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.month,
    required this.onDayTap,
    required this.isStart,
    required this.isEnd,
    required this.isInRange,
  });

  final int year;
  final int month;
  final void Function(DateTime) onDayTap;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;
  final bool Function(DateTime) isInRange;

  static const _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  static const _monthNames = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    // weekday: 1=Mon … 7=Sun → offset to Sun-first grid
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthNames[month - 1],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius:
                  BorderRadius.circular(AppConstants.cardRadius),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Weekday header row
                Row(
                  children: _weekdays
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),

                // Day cells
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 36,
                  ),
                  itemCount: firstWeekday + daysInMonth,
                  itemBuilder: (context, idx) {
                    if (idx < firstWeekday) return const SizedBox();
                    final day = idx - firstWeekday + 1;
                    final date = DateTime(year, month, day);
                    final start = isStart(date);
                    final end = isEnd(date);
                    final inRange = isInRange(date);

                    Color? bg;
                    Color textColor = AppColors.textPrimary;
                    if (start || end) {
                      bg = AppColors.primary;
                      textColor = Colors.white;
                    } else if (inRange) {
                      bg = AppColors.primary.withValues(alpha: 0.15);
                      textColor = AppColors.primary;
                    }

                    return GestureDetector(
                      onTap: () => onDayTap(date),
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: (start || end)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
