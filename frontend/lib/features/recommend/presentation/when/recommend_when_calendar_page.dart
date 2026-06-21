import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/date_range_calendar.dart';

class RecommendWhenCalendarPage extends StatefulWidget {
  const RecommendWhenCalendarPage({super.key});

  @override
  State<RecommendWhenCalendarPage> createState() =>
      _RecommendWhenCalendarPageState();
}

class _RecommendWhenCalendarPageState extends State<RecommendWhenCalendarPage> {
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[
                    Color(0xFF020B10),
                    Color(0xFF07161D),
                    Color(0xFF020B10),
                  ]
                : <Color>[
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
                  Expanded(
                    child: Text(
                      "When's your trip?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: DateRangeCalendar(
                onRangeChanged: (DateTimeRange? range) =>
                    setState(() => _selectedRange = range),
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
                      onPressed: _selectedRange != null
                          ? () => context.push(
                              AppRoutes.recommendWhenResults,
                              extra: _selectedRange,
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
