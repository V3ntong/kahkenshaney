import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Premium color palette — blue core with sky, mint, amber accents.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primarySurface = Color(0xFFEFF6FF);

  // Floating navigation â€” deliberately part of the blue brand family rather
  // than a neutral black/orange treatment.
  static const Color navigationSurface = Color(0xFF0F2747);
  static const Color navigationActive = Color(0xFF3B82F6);
  static const Color navigationInactive = Color(0xFF9CB4D0);
  static const Color navigationBorder = Color(0x337DB4FF);

  // Reusable frosted surfaces for overlays on photography.
  static const Color glassLightTint = Color(0xCCFFFFFF);
  static const Color glassDarkTint = Color(0xCC0F2747);
  static const Color glassBorder = Color(0x99FFFFFF);

  // ── Secondary / Accent ─────────────────────────────────
  static const Color secondary = Color(0xFF3B82F6);
  static const Color accent = Color(0xFF22C55E);

  // ── Backgrounds ────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color cardBorder = Color(0xFFE5E7EB);

  // ── Text ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textOnPrimary = Colors.white;

  // ── Borders & Dividers ─────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF1F5F9);

  // ── Semantic ───────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ── Gradient ───────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF22C55E)],
  );

  // ── Soft shadow (blur 20, opacity 8%, y offset 6) ─────
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x14256EB3), blurRadius: 20, offset: Offset(0, 6)),
  ];
}

/// Builds the full Material 3 [ThemeData].
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,

    // ── AppBar ────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),

    // ── Input Decoration ──────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space16,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
      prefixIconColor: AppColors.textTertiary,
      suffixIconColor: AppColors.textTertiary,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
    ),

    // ── Text Button ───────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
    ),

    // ── Elevated Button ───────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24,
          vertical: AppTokens.space16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: AppTokens.bodyStrong.copyWith(color: Colors.white),
      ),
    ),

    // ── Filled Button ─────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24,
          vertical: AppTokens.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: AppTokens.bodyStrong.copyWith(color: Colors.white),
      ),
    ),

    // ── Outlined Button ───────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24,
          vertical: AppTokens.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: AppTokens.bodyStrong.copyWith(color: AppColors.primary),
      ),
    ),

    // ── Card ──────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Chip ──────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primarySurface,
      disabledColor: AppColors.surfaceVariant,
      labelStyle: AppTokens.labelSmall.copyWith(color: AppColors.textPrimary),
      secondaryLabelStyle: AppTokens.labelSmall.copyWith(
        color: AppColors.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      side: const BorderSide(color: AppColors.cardBorder),
    ),

    // ── SnackBar ──────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
    ),

    // ── Divider ───────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 0,
    ),

    // ── ListTile ──────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space4,
      ),
    ),
  );
}
