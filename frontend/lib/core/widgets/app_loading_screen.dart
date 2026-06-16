import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({
    super.key,
    this.message = 'Loading...',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark
        ? const Color(0xFF071A24)
        : const Color(0xFFEAFBFF);
    final Color panel = isDark ? const Color(0xFF102A36) : Colors.white;
    final Color text = isDark ? const Color(0xFFE6F7FF) : AppColors.textPrimary;
    final Color subText = isDark
        ? const Color(0xFF9BB7C5)
        : AppColors.textSecondary;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 58 : 76,
          height: compact ? 58 : 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[AppColors.primaryLight, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(compact ? 18 : 24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Icon(
                Icons.travel_explore_rounded,
                size: compact ? 20 : 24,
                color: Colors.white,
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 14 : 22),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: text,
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Preparing your Vietnam journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: content),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const <Color>[Color(0xFF071A24), Color(0xFF0B2B30)]
                : const <Color>[Color(0xFFEAFBFF), Color(0xFFD9FFF8)],
          ),
        ),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
            decoration: BoxDecoration(
              color: panel.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
