import 'package:flutter/material.dart';

/// Design tokens mirroring the `restoraerp` daisyUI theme in
/// `front/src/app/globals.css`, so the terminal and the web admin read as one
/// product. Names follow the CSS variables they come from.
class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFF0F6E5C);
  static const Color primaryContent = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFF4A825);
  static const Color secondaryContent = Color(0xFF1A1D1F);

  /// Lighter teal used only as the far end of the primary gradient; the web
  /// uses a flat primary, this keeps CTAs from looking dead on a large screen.
  static const Color primaryAlt = Color(0xFF178A72);

  // Surfaces
  static const Color base100 = Color(0xFFFAFAF8); // cards, sheets
  static const Color base200 = Color(0xFFF2F5F4); // page background
  static const Color base300 = Color(0xFFE4E7E6); // borders, dividers
  static const Color baseContent = Color(0xFF1A1D1F);

  /// Aliases used throughout the POS widgets.
  static const Color surface = base100;
  static const Color canvas = base200;
  static const Color border = base300;
  static const Color surfaceMuted = base200;

  // Content
  static const Color textPrimary = baseContent;
  static const Color textSecondary = Color(0xFF5B6266); // --color-content-secondary
  static const Color textMuted = Color(0xFF9CA3A6); // --color-content-muted

  // Semantic
  static const Color success = Color(0xFF1E8E5A);
  static const Color warning = Color(0xFFF4A825);
  static const Color danger = Color(0xFFD64545);
  static const Color info = Color(0xFF2F80ED);

  /// Tints of the semantic colours for banners and chips. The web gets these
  /// from daisyUI's `alert-*` components; they are spelled out here.
  static const Color successBg = Color(0xFFE9F5EF);
  static const Color successBorder = Color(0xFFBFE3D0);
  static const Color successText = Color(0xFF14663F);

  static const Color warningBg = Color(0xFFFEF6E7);
  static const Color warningBorder = Color(0xFFF8DFA8);
  static const Color warningText = Color(0xFF8A5B08);

  static const Color dangerBg = Color(0xFFFCECEC);
  static const Color dangerBorder = Color(0xFFF3C4C4);
  static const Color dangerText = Color(0xFFA83232);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryAlt],
  );
}

/// Corner radii from the theme's `--radius-*` variables.
class AppRadius {
  const AppRadius._();

  static const double selector = 8; // --radius-selector: 0.5rem
  static const double field = 10; // --radius-field:    0.625rem
  static const double box = 16; // --radius-box:      1rem
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryContent,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryContent,
      surface: AppColors.surface,
      onSurface: AppColors.baseContent,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
  );

  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: _fieldBorder(_fieldOutline),
      enabledBorder: _fieldBorder(_fieldOutline),
      // The web gives focused fields a soft brand ring rather than a hard line.
      focusedBorder: _fieldBorder(AppColors.primary, width: 1.8),
      errorBorder: _fieldBorder(AppColors.danger),
      focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.8),
      disabledBorder: _fieldBorder(AppColors.base300),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryContent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: _fieldOutline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// `color-mix(base-content 25%, transparent)` from the web field styling,
/// flattened against the card background.
const Color _fieldOutline = Color(0xFFC5C8C9);

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );

/// Formats an amount with the venue's currency symbol.
String money(String currency, double value) =>
    '$currency${value.toStringAsFixed(2)}';
