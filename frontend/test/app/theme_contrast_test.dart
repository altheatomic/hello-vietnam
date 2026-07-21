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
