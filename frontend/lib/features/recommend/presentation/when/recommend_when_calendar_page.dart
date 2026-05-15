import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

class RecommendWhenCalendarPage extends StatefulWidget {
  const RecommendWhenCalendarPage({super.key});

  @override
  State<RecommendWhenCalendarPage> createState() =>
      _RecommendWhenCalendarPageState();
}

class _RecommendWhenCalendarPageState extends State<RecommendWhenCalendarPage> {
  int _year = DateTime.now().year;
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

  bool get _hasRange => _start != null && _end != null;

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null) {
        _start = day;
        _end = null;
        return;
      }

      if (_end == null) {
        if (_isSameDate(day, _start!)) {
          _start = null;
          return;
        }

        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        return;
      }

      final bool isTappedStart = _isSameDate(day, _start!);
      final bool isTappedEnd = _isSameDate(day, _end!);

      if (isTappedStart && isTappedEnd) {
        _start = null;
        _end = null;
        return;
      }

      if (isTappedStart) {
        _start = _end;
        _end = null;
        return;
      }

      if (isTappedEnd) {
        _end = null;
        return;
      }

      _start = day;
      _end = null;
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

  int get _durationDays {
    if (!_hasRange) return 0;
    return _end!.difference(_start!).inDays + 1;
  }

  String get _summaryText {
    if (_start == null && _end == null) return 'Select your travel dates';
    if (_start != null && _end == null) {
      return '${_monthShort(_start!.month)} ${_start!.day}';
    }
    return '${_monthShort(_start!.month)} ${_start!.day}  →  ${_monthShort(_end!.month)} ${_end!.day}';
  }

  String get _durationText {
    if (!_hasRange) return 'Choose a start and end date';
    return '$_durationDays ${_durationDays == 1 ? 'day' : 'days'}';
  }

  String _monthShort(int month) => _monthNames[month - 1].substring(0, 3);

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFFE9FBFF),
              const Color(0xFFF6FDFF),
              Colors.white.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                topInset + 8,
                AppConstants.pagePadding,
                10,
              ),
              child: Row(
                children: <Widget>[
                  _CircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      "When's your trip?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _CircleButton(
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
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _CircleButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => setState(() => _year++),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _RangeSummaryCard(
                summary: _summaryText,
                duration: _durationText,
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
                      monthName: _monthNames[index],
                      weekdayLabels: _weekdayLabels,
                      onDayTap: _onDayTap,
                      isStart: _isStart,
                      isEnd: _isEnd,
                      isInRange: _isInRange,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF2EB9F8).withValues(alpha: 0.26),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _hasRange
                          ? () => context.push(
                              AppRoutes.recommendWhenResults,
                              extra: DateTimeRange(start: _start!, end: _end!),
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF2EA7F8),
                        disabledBackgroundColor: const Color(
                          0xFF2EA7F8,
                        ).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: const Color(0xFF6B7280), size: 20),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
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
              isComplete ? duration : 'Pick dates',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isComplete
                    ? const Color(0xFF2EA7F8)
                    : const Color(0xFF94A3B8),
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
    required this.onDayTap,
    required this.isStart,
    required this.isEnd,
    required this.isInRange,
  });

  final int year;
  final int month;
  final String monthName;
  final List<String> weekdayLabels;
  final void Function(DateTime) onDayTap;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;
  final bool Function(DateTime) isInRange;

  @override
  Widget build(BuildContext context) {
    final int firstWeekday = DateTime(year, month, 1).weekday % 7;
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final DateTime today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
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
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
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
              final bool start = isStart(date);
              final bool end = isEnd(date);
              final bool inRange = isInRange(date);
              final bool isToday =
                  today.year == date.year &&
                  today.month == date.month &&
                  today.day == date.day;

              Color textColor = const Color(0xFF64748B);
              Color? fillColor;
              Border? border;

              if (start || end) {
                fillColor = const Color(0xFF2EA7F8);
                textColor = Colors.white;
              } else if (inRange) {
                fillColor = const Color(0xFFBFEFFF);
                textColor = const Color(0xFF2EA7F8);
              } else if (isToday) {
                border = Border.all(
                  color: const Color(0xFF2EA7F8).withValues(alpha: 0.55),
                );
              }

              return GestureDetector(
                onTap: () => onDayTap(date),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: fillColor,
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
              );
            },
          ),
        ],
      ),
    );
  }
}
