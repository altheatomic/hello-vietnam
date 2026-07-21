import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';

void main() {
  test('light secondary text has enhanced contrast on the app background', () {
    expect(
      _contrastRatio(AppColors.textSecondary, AppColors.background),
      greaterThanOrEqualTo(7),
    );
  });

  test('light and dark themes expose readable semantic colors', () {
    final ThemeData light = buildTheme();
    final ThemeData dark = buildDarkTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(
      _contrastRatio(
        light.colorScheme.onSurface,
        light.scaffoldBackgroundColor,
      ),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrastRatio(dark.colorScheme.onSurface, dark.scaffoldBackgroundColor),
      greaterThanOrEqualTo(7),
    );
  });

  test('audited dark-mode surfaces do not hardcode light-theme text colors', () {
    final RegExp lightTextColor = RegExp(
      r'AppColors\.(?:textPrimary|textSecondary)|'
      r'Color\(0xFF(?:101828|1A1A2E|1A1A1A|121212|222222|232323|2B2B2B|'
      r'1B1B1B|1F1F1F|202020|2C2C2C|4A5565|475569|5F5F5F|666666|6A7282|'
      r'6B7280|6E7A86|7E8B97)\)',
    );
    final List<String> violations = <String>[];
    const List<String> auditedFiles = <String>[
      'lib/core/widgets/empty_state.dart',
      'lib/features/auth/presentation/forgot_password_page.dart',
      'lib/features/auth/presentation/login_page.dart',
      'lib/features/auth/presentation/register_page.dart',
      'lib/features/forum/presentation/forum_report_post_page.dart',
      'lib/features/location/presentation/quick_location_flow.dart',
      'lib/features/planner/presentation/trip_budget_page.dart',
      'lib/features/planner/presentation/trip_day_detail_page.dart',
      'lib/features/planner/presentation/trip_map_page.dart',
      'lib/features/profile/presentation/change_password_page.dart',
      'lib/features/profile/presentation/currency_page.dart',
      'lib/features/profile/presentation/delete_user_data_page.dart',
      'lib/features/profile/presentation/edit_profile_page.dart',
      'lib/features/profile/presentation/language_page.dart',
      'lib/features/profile/presentation/rank_benefits_page.dart',
      'lib/features/profile/presentation/voucher_detail_page.dart',
      'lib/features/profile/presentation/voucher_page.dart',
      'lib/features/recommend/presentation/where/recommend_where_search_page.dart',
      'lib/features/reviews/presentation/review_composer_sheet.dart',
      'lib/features/reviews/presentation/review_section.dart',
    ];

    for (final String path in auditedFiles) {
      final List<String> lines = File(path).readAsLinesSync();
      for (int index = 0; index < lines.length; index++) {
        if (lightTextColor.hasMatch(lines[index])) {
          violations.add('$path:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use Theme.of(context).colorScheme.onSurface/onSurfaceVariant so '
          'text and icons remain readable in dark mode:\n${violations.join('\n')}',
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final double lighter =
      foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final double darker =
      foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
