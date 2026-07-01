import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';

class TravelPreferencesSummaryCard extends StatelessWidget {
  const TravelPreferencesSummaryCard({
    super.key,
    required this.preferences,
    required this.onRetune,
    this.title = 'Tailored to your travel taste',
    this.description,
    this.buttonLabel = 'Refine',
  });

  final UserTravelPreferences preferences;
  final VoidCallback onRetune;
  final String title;
  final String? description;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isVietnamese =
        AppLanguageScope.languageOf(context) == AppLanguage.vietnamese;
    final String styleLabel = preferences.travelStyles.isEmpty
        ? (isVietnamese ? 'du lịch' : 'travel')
        : context.l10n.ui(preferences.travelStyles.first.label).toLowerCase();
    final String budgetLabel = context.l10n
        .ui(preferences.budgetLevel.label)
        .toLowerCase();
    final String paceLabel = context.l10n
        .ui(preferences.pace.label)
        .toLowerCase();
    final String summaryText =
        description ??
        (isVietnamese
            ? 'Chúng tôi đang ưu tiên thành phố và điểm nổi bật theo gu $styleLabel, ngân sách $budgetLabel và nhịp đi $paceLabel.'
            : 'We are prioritizing cities and highlights around '
                  '$styleLabel, $budgetLabel comfort, and a '
                  '$paceLabel rhythm.');

    return GlassCard(
      borderRadius: 28,
      blur: 18,
      opacity: isDark ? 0.52 : 0.25,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.ui(title),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : const Color(0xFF1C3550),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRetune,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryLight.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.l10n.ui(buttonLabel),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summaryText,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.42,
              color: isDark ? const Color(0xFFA9BCC7) : const Color(0xFF607287),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preferences.summaryLabels
                .map(
                  (String label) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      context.l10n.ui(label),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFD6F3FF)
                            : const Color(0xFF54708E),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
