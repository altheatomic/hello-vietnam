import 'package:flutter/material.dart';

/// App color palette — inspired by reference UI (sky‑blue travel app)
class AppColors {
  AppColors._();

  // Primary blues
  static const Color primaryLight = Color(0xFF87CEEB); // sky blue
  static const Color primary = Color(0xFF4DB8E8);
  static const Color primaryDark = Color(0xFF2196C8);
  static const Color primaryApple = Color(0xFF0A84FF);

  // Accents
  static const Color accent = Color(0xFF56CCF2);
  static const Color accentGold = Color(0xFFFFF176);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF9FCFF);
  static const Color surfaceGlass = Color(0x26FFFFFF); // 15% white

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textOnPrimary = Colors.white;

  // Misc
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);
  static const Color starColor = Color(0xFFFFC107);

  // Admin dashboard specific
  static const Color adminSidebar = Color(0xFF1A2332);
}

const BorderRadius _appleRadius = BorderRadius.all(Radius.circular(24));
const BorderRadius _appleRadiusLarge = BorderRadius.all(Radius.circular(28));
const Duration _appleMotion = Duration(milliseconds: 300);

ButtonStyle _primaryButtonStyle({
  required Color background,
  required Color foreground,
  required Color shadow,
}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 52)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
    elevation: WidgetStateProperty.resolveWith<double>((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 0;
      return 2;
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return background.withValues(alpha: 0.35);
      }
      if (states.contains(WidgetState.pressed)) {
        return background.withValues(alpha: 0.88);
      }
      return background;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return foreground.withValues(alpha: 0.55);
      }
      return foreground;
    }),
    overlayColor: WidgetStatePropertyAll<Color>(
      foreground.withValues(alpha: 0.10),
    ),
    shadowColor: WidgetStatePropertyAll<Color>(shadow.withValues(alpha: 0.24)),
    surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    animationDuration: _appleMotion,
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
  );
}

ButtonStyle _outlinedButtonStyle({
  required Color accent,
  required Color foreground,
  required Color disabled,
}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 50)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 22, vertical: 13),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
    side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: disabled.withValues(alpha: 0.35));
      }
      return BorderSide(color: accent.withValues(alpha: 0.38), width: 1.2);
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return accent.withValues(alpha: 0.12);
      }
      return accent.withValues(alpha: 0.06);
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabled.withValues(alpha: 0.55);
      }
      return foreground;
    }),
    overlayColor: WidgetStatePropertyAll<Color>(accent.withValues(alpha: 0.10)),
    animationDuration: _appleMotion,
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
  );
}

ButtonStyle _textButtonStyle({required Color accent, required Color disabled}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 44)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabled.withValues(alpha: 0.55);
      }
      return accent;
    }),
    overlayColor: WidgetStatePropertyAll<Color>(accent.withValues(alpha: 0.10)),
    animationDuration: _appleMotion,
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      primaryContainer: const Color(0xFFDFF5FF),
      onPrimaryContainer: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.divider.withValues(alpha: 0.8),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: 0,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _primaryButtonStyle(
        background: AppColors.primary,
        foreground: AppColors.textOnPrimary,
        shadow: AppColors.primaryDark,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _primaryButtonStyle(
        background: AppColors.primary,
        foreground: AppColors.textOnPrimary,
        shadow: AppColors.primaryDark,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedButtonStyle(
        accent: AppColors.primary,
        foreground: AppColors.primaryDark,
        disabled: AppColors.textSecondary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _textButtonStyle(
        accent: AppColors.primaryDark,
        disabled: AppColors.textSecondary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 44)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
        foregroundColor: const WidgetStatePropertyAll<Color>(
          AppColors.textPrimary,
        ),
        overlayColor: WidgetStatePropertyAll<Color>(
          AppColors.primary.withValues(alpha: 0.10),
        ),
        animationDuration: _appleMotion,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: _appleRadius),
      shadowColor: AppColors.shadow.withValues(alpha: 0.7),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.4),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      disabledColor: AppColors.divider,
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      shape: const StadiumBorder(),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: _appleRadiusLarge),
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
        height: 1.45,
        letterSpacing: 0,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primaryDark,
      unselectedItemColor: AppColors.textSecondary,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: AppColors.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final bool selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          size: selected ? 25 : 23,
        );
      }),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.35,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0,
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  const Color darkBackground = Color(0xFF020B10);
  const Color darkSurface = Color(0xFF0B1A22);
  const Color darkSurfaceHigh = Color(0xFF122832);
  const Color darkText = Color(0xFFF5FBFF);
  const Color darkTextSecondary = Color(0xFFA9BCC7);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: darkText,
      primary: AppColors.primaryLight,
      onPrimary: darkBackground,
      secondary: AppColors.accent,
      onSecondary: darkBackground,
      primaryContainer: darkSurfaceHigh,
      onPrimaryContainer: darkText,
      surfaceContainerHighest: darkSurfaceHigh,
      outline: Colors.white24,
    ),
    scaffoldBackgroundColor: darkBackground,
    canvasColor: darkBackground,
    dividerColor: Colors.white.withValues(alpha: 0.10),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryLight,
        letterSpacing: 0,
      ),
      iconTheme: IconThemeData(color: darkText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _primaryButtonStyle(
        background: AppColors.primaryLight,
        foreground: darkBackground,
        shadow: AppColors.primary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _primaryButtonStyle(
        background: AppColors.primaryLight,
        foreground: darkBackground,
        shadow: AppColors.primary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedButtonStyle(
        accent: AppColors.primaryLight,
        foreground: AppColors.primaryLight,
        disabled: darkTextSecondary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _textButtonStyle(
        accent: AppColors.primaryLight,
        disabled: darkTextSecondary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 44)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
        foregroundColor: const WidgetStatePropertyAll<Color>(darkText),
        overlayColor: WidgetStatePropertyAll<Color>(
          AppColors.primaryLight.withValues(alpha: 0.12),
        ),
        animationDuration: _appleMotion,
      ),
    ),
    cardTheme: const CardThemeData(
      color: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: _appleRadius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _appleRadius,
        borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1.4),
      ),
      hintStyle: const TextStyle(
        color: darkTextSecondary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.10),
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.20),
      disabledColor: darkSurfaceHigh,
      labelStyle: const TextStyle(
        color: darkText,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      shape: const StadiumBorder(),
      side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.12)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: _appleRadiusLarge),
      titleTextStyle: const TextStyle(
        color: darkText,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      contentTextStyle: const TextStyle(
        color: darkTextSecondary,
        fontSize: 15,
        height: 1.45,
        letterSpacing: 0,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurfaceHigh,
      contentTextStyle: const TextStyle(
        color: darkText,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: darkTextSecondary,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: darkSurface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryLight.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final bool selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.primaryLight : darkTextSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primaryLight : darkTextSecondary,
          size: selected ? 25 : 23,
        );
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary.withValues(alpha: 0.5);
        }
        return darkSurfaceHigh;
      }),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: darkText,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: darkText,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: darkText,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: darkText,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: darkText,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: darkTextSecondary,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: darkTextSecondary,
        height: 1.35,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: darkTextSecondary,
        letterSpacing: 0,
      ),
    ),
  );
}
