import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/app_scaffold.dart';
import 'package:hellovietnam/core/widgets/search_bar_widget.dart';
import 'widgets/choice_card.dart';

/// Entry screen for the Recommend feature.
///
/// Presents two flows the user can choose:
///   - **Where** — search a destination by name.
///   - **When** — pick travel dates, then receive destination suggestions.
class RecommendPage extends StatelessWidget {
  const RecommendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Recommend',
      showBack: true,
      // Search bar sits inside the blue header — mirrors the Home pattern.
      headerBottom: SearchBarWidget(
        hintText: 'Search destinations',
        onSearch: (q) => context.push(
          AppRoutes.recommendWhereSearch,
          extra: q,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding,
          28,
          AppConstants.pagePadding,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please choose:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.accentGold,
              ),
            ),
            const SizedBox(height: 16),

            // ── Where card ────────────────────────────────
            ChoiceCard(
              label: 'Where do you want to go?',
              backgroundColor: AppColors.primary,
              onTap: () => context.push(AppRoutes.recommendWhereSearch),
            ),
            const SizedBox(height: 14),

            // ── When card ─────────────────────────────────
            ChoiceCard(
              label: 'When are you free to travel?',
              backgroundColor: AppColors.accentGold,
              onTap: () => context.push(AppRoutes.recommendWhenCalendar),
            ),
          ],
        ),
      ),
    );
  }
}
