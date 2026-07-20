import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';

/// A reusable date-range calendar body.
///
/// Renders a year navigation row, a range-summary card, and a scrollable
/// list of month grids. The widget manages its own internal selection state
/// and notifies the parent via [onRangeChanged] whenever the selection
/// changes (including when it becomes null after a deselection).
///
/// Intended to be placed inside a widget that already provides a bounded
/// height (e.g. wrapped in [Expanded] by the caller), because the month
/// list is rendered with [ListView.builder] and requires infinite vertical
/// space otherwise.
class DateRangeCalendar extends StatefulWidget {
  const DateRangeCalendar({
    super.key,
    this.initialRange,
    this.firstDate,
    required this.onRangeChanged,
  });

  final DateTimeRange? initialRange;
  final DateTime? firstDate;
  final void Function(DateTimeRange?) onRangeChanged;

  @override
  State<DateRangeCalendar> createState() => _DateRangeCalendarState();
}

class _DateRangeCalendarState extends State<DateRangeCalendar> {
  late int _year;
  DateTime? _start;
  DateTime? _end;

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayLabels = <String>[
    'Su',
    'Mo',
    'Tu',
    'We',
    'Th',
    'Fr',
    'Sa',
  ];

  @override
  void initState() {
    super.initState();
    final DateTimeRange? init = widget.initialRange;
    _start = init?.start;
    _end = init?.end;
    _year = (_start ?? DateTime.now()).year;
  }

  bool get _hasRange => _start != null && _end != null;

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _onDayTap(DateTime day) {
    final DateTime? firstDate = widget.firstDate;
    if (firstDate != null && day.isBefore(_dateOnly(firstDate))) return;
    setState(() {
      if (_start == null) {
        _start = day;
        _end = null;
      } else if (_end == null) {
        if (_isSameDate(day, _start!)) {
          _start = null;
        } else if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
      } else {
        final bool tappedStart = _isSameDate(day, _start!);
        final bool tappedEnd = _isSameDate(day, _end!);
        if (tappedStart && tappedEnd) {
          _start = null;
          _end = null;
        } else if (tappedStart) {
          _start = _end;
          _end = null;
        } else if (tappedEnd) {
          _end = null;
        } else {
          _start = day;
          _end = null;
        }
      }
    });
    widget.onRangeChanged(
      _hasRange ? DateTimeRange(start: _start!, end: _end!) : null,
    );
  }

  bool _isStart(DateTime d) => _start != null && _isSameDate(d, _start!);

  bool _isEnd(DateTime d) => _end != null && _isSameDate(d, _end!);

  bool _isInRange(DateTime d) {
    if (_start == null || _end == null) return false;
    return d.isAfter(_start!) && d.isBefore(_end!);
  }

  int get _durationDays {
    if (!_hasRange) return 0;
    return _end!.difference(_start!).inDays + 1;
  }

  String _monthShort(int month) => _monthNames[month - 1].substring(0, 3);

  String get _summaryText {
    if (_start == null) return 'Select your travel dates';
    if (_end == null) return '${_monthShort(_start!.month)} ${_start!.day}';
    return '${_monthShort(_start!.month)} ${_start!.day}'
        '  →  '
        '${_monthShort(_end!.month)} ${_end!.day}';
  }

  String get _durationText {
    if (!_hasRange) return 'Choose a start and end date';
    return '$_durationDays ${_durationDays == 1 ? 'day' : 'days'}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _NavCircleButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _year--),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.94)
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$_year',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _NavCircleButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => setState(() => _year++),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _RangeSummaryCard(
            summary: context.l10n.ui(_summaryText),
            duration: context.l10n.ui(_durationText),
            isComplete: _hasRange,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: 12,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _MonthCard(
                  year: _year,
                  month: index + 1,
                  monthName: context.l10n.ui(_monthNames[index]),
                  weekdayLabels: _weekdayLabels
                      .map(context.l10n.ui)
                      .toList(growable: false),
                  hasCompletedRange: _hasRange,
                  firstDate: widget.firstDate,
                  onDayTap: _onDayTap,
                  isStart: _isStart,
                  isEnd: _isEnd,
                  isInRange: _isInRange,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: isDark
                ? Theme.of(context).colorScheme.onSurface
                : const Color(0xFF6B7280),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _RangeSummaryCard extends StatelessWidget {
  const _RangeSummaryCard({
    required this.summary,
    required this.duration,
    required this.isComplete,
  });

  final String summary;
  final String duration;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.96);
    final Color primaryText = Theme.of(context).colorScheme.onSurface;
    final Color mutedText = isDark
        ? const Color(0xFFA9BCC7)
        : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Color(0xFF2EA7F8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFC9F1FD)
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isComplete ? duration : context.l10n.ui('Pick dates'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isComplete ? const Color(0xFF2EA7F8) : mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.year,
    required this.month,
    required this.monthName,
    required this.weekdayLabels,
    required this.hasCompletedRange,
    this.firstDate,
    required this.onDayTap,
    required this.isStart,
    required this.isEnd,
    required this.isInRange,
  });

  final int year;
  final int month;
  final String monthName;
  final List<String> weekdayLabels;
  final bool hasCompletedRange;
  final DateTime? firstDate;
  final void Function(DateTime) onDayTap;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;
  final bool Function(DateTime) isInRange;

  @override
  Widget build(BuildContext context) {
    final int firstWeekday = DateTime(year, month, 1).weekday % 7;
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final DateTime today = DateTime.now();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryText = Theme.of(context).colorScheme.onSurface;
    final Color mutedText = isDark
        ? const Color(0xFFA9BCC7)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            monthName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: weekdayLabels
                .map(
                  (String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedText.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 38,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (BuildContext context, int index) {
              if (index < firstWeekday) return const SizedBox();
              final int day = index - firstWeekday + 1;
              final DateTime date = DateTime(year, month, day);
              final DateTime? minimum = firstDate == null
                  ? null
                  : DateTime(firstDate!.year, firstDate!.month, firstDate!.day);
              final bool disabled = minimum != null && date.isBefore(minimum);
              final bool start = isStart(date);
              final bool end = isEnd(date);
              final bool inRange = isInRange(date);
              final bool isRangeDay =
                  hasCompletedRange && (start || end || inRange);
              final bool isToday =
                  today.year == date.year &&
                  today.month == date.month &&
                  today.day == date.day;
              final bool isFirstColumn = index % 7 == 0;
              final bool isLastColumn = index % 7 == 6;

              Color textColor = mutedText;
              Color? bubbleFillColor;
              Border? border;

              if (disabled) {
                textColor = mutedText.withValues(alpha: 0.32);
              } else if (start || end) {
                bubbleFillColor = const Color(0xFF2EA7F8);
                textColor = Colors.white;
              } else if (inRange) {
                textColor = const Color(0xFF2EA7F8);
              } else if (isToday) {
                border = Border.all(
                  color: const Color(0xFF2EA7F8).withValues(alpha: 0.55),
                );
              }

              return GestureDetector(
                onTap: disabled ? null : () => onDayTap(date),
                child: Stack(
                  children: <Widget>[
                    if (isRangeDay)
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFEFFF),
                            borderRadius: BorderRadius.horizontal(
                              left: start || isFirstColumn
                                  ? const Radius.circular(999)
                                  : Radius.zero,
                              right: end || isLastColumn
                                  ? const Radius.circular(999)
                                  : Radius.zero,
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Container(
                        width: 31,
                        height: 31,
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: bubbleFillColor,
                          shape: BoxShape.circle,
                          border: border,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: (start || end)
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
