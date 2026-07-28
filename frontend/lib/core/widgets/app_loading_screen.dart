import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/widgets/journey_loading/journey_loading_timeline.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({
    super.key,
    this.message = 'Loading...',
    this.compact = false,
    this.isComplete = false,
    this.onExitComplete,
    this.timelineFactory,
  });

  final String message;
  final bool compact;
  final bool isComplete;
  final VoidCallback? onExitComplete;
  final JourneyLoadingTimeline Function()? timelineFactory;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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

    return VietnamJourneyLoadingScreen(
      message: message,
      isComplete: isComplete,
      onExitComplete: onExitComplete,
      timelineFactory: timelineFactory,
    );
  }
}
