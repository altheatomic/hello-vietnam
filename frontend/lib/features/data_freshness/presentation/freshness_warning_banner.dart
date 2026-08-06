import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';

class FreshnessWarningBanner extends StatelessWidget {
  const FreshnessWarningBanner({super.key, required this.info});

  final ContentFreshnessInfo info;

  @override
  Widget build(BuildContext context) {
    final bool review = info.status == ContentFreshnessStatus.needsReview;
    final String message = info.warning?.trim().isNotEmpty == true
        ? info.warning!.trim()
        : review
        ? context.l10n.ui('This information is being checked again.')
        : context.l10n.ui('Information has not been verified recently');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: review
            ? Colors.orange.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: review
              ? Colors.orange.withValues(alpha: 0.45)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            review ? Icons.manage_search_outlined : Icons.info_outline,
            size: 20,
            color: review
                ? Colors.orange.shade800
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
