import 'package:flutter/material.dart';

/// Consistent page-level heading used at the top of every admin page.
///
/// Renders a [title] in [TextTheme.headlineMedium] (22 px / w700 / textPrimary)
/// and an optional [subtitle] in [TextTheme.bodyMedium], matching the section
/// title hierarchy from Home's RecommendationSection and AppScaffold.
///
/// A [trailing] slot accepts any widget aligned to the right — typically a
/// primary-style action button (e.g., "Add User") or a filter row.
///
/// A fixed 24 px gap below the header separates it from the page content,
/// matching the desktop [AdminPageContainer.contentPadding] rhythm.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Optional widget pinned to the right of the title row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle case final sub?) ...[
                  const SizedBox(height: 4),
                  Text(sub, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            );
            final action = trailing;

            if (action == null) return titleBlock;
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 14), action],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 20),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
