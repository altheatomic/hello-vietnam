## Project overview

This is a Flutter app using feature-first structure.
Main visual reference is the Home feature.
When building new screens, prioritize consistency with the existing Home UI over Figma styling.

## Source of truth

UI source of truth:

1. lib/app/theme.dart
2. lib/core/config/app_constants.dart
3. lib/core/widgets/glass_card.dart
4. lib/core/widgets/search_bar_widget.dart
5. lib/features/home/presentation/home_page.dart
6. lib/features/home/presentation/widgets/\*

Reuse these before creating new UI:

- SearchBarWidget
- GlassCard
- RecommendationCard
- RecommendationSection
- FeatureGrid

## UI rules

- Do not hardcode colors if an existing theme value can be used.
- Do not invent a new card style if glass_card.dart or existing home cards can be adapted.
- Do not invent a new search bar if search_bar_widget.dart can be reused or extended.
- Prefer existing spacing rhythm from Home.
- Prefer existing border radius from themed widgets or Home components.
- Keep section title style consistent with Home.
- Keep image corner radius and card shadow treatment consistent with Home.
- Reuse AppScaffold where possible.

## Architecture rules

- Follow current feature-first structure.
- Keep presentation widgets small and reusable.
- If a UI pattern appears 2+ times, extract a widget.
- Avoid changing unrelated files.
- Avoid broad refactors unless explicitly asked.

## Output rules

For every task:

1. First inspect relevant files.
2. State which existing components/styles will be reused.
3. Then implement.
4. At the end, summarize:
   - files changed
   - reused patterns from Home
   - any new widget created
   - any places that may still need manual design review

## Figma handling

Treat Figma as layout inspiration only.
If Figma conflicts with Home/theme, preserve Home/theme.
