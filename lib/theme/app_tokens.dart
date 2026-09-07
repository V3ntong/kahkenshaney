import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Centralized design tokens — typography scale, spacing scale, radius scale,
/// and shadow presets. Import this file instead of hardcoding values.
///
/// Usage:
/// ```dart
/// Text('Hello', style: AppTokens.labelLarge)
/// SizedBox(height: AppTokens.space4)
/// Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppTokens.radiusLg)))
/// ```
class AppTokens {
  AppTokens._();

  // ── Typography Scale ─────────────────────────────────────────────────
  // Based on the app's existing Inter font with a consistent type ramp.

  /// 11 / w800 — tiny labels, badges
  static const TextStyle labelTiny = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    color: AppColors.textPrimary,
  );

  /// 12 / w600 — section captions, meta text
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
  );

  /// 13 / w600 — secondary labels, chip text
  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// 14 / w600 — field labels, tile titles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 14 / w700 — card titles, emphasis labels
  static const TextStyle labelBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// 15 / w400 — body text, input text
  static const TextStyle bodyDefault = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// 15 / w600 — button text, emphasis body
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 14 / w400 — descriptions, secondary body
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// 16 / w700 — section titles, sheet headers
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// 18 / w700 — screen titles, empty state titles
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// 20 / w700 — hero headlines
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// 24 / w800 — display text
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// 32+ / w800 — hero numbers (BebasNeue used in greeting/summary)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    color: AppColors.textPrimary,
  );

  // ── Spacing Scale ────────────────────────────────────────────────────
  // 4px base unit. Use these instead of magic numbers.

  static const double space0 = 0;
  static const double space1 = 1;
  static const double space2 = 2;
  static const double space3 = 3;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space28 = 28;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // ── Radius Scale ─────────────────────────────────────────────────────

  /// Handles, tiny elements
  static const double radiusXs = 4;

  /// Badges, status pills, small chips
  static const double radiusSm = 8;

  /// Buttons, inputs, medium elements
  static const double radiusMd = 14;

  /// Cards, sheets, large surfaces
  static const double radiusLg = 20;

  /// Hero cards, overlays
  static const double radiusXl = 24;

  /// Fully rounded pills
  static const double radiusPill = 999;

  // ── Shadow Presets ───────────────────────────────────────────────────

  /// Subtle card elevation (the standard for most cards)
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0A0F2747),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Medium elevation (bottom nav, floating elements)
  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x140F2747),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  /// High elevation (modals, overlays)
  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1A0F2747),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Primary-colored glow (for featured/active elements)
  static const List<BoxShadow> shadowPrimary = [
    BoxShadow(
      color: Color(0x332563EB),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // ── Semantic Badge Colors ────────────────────────────────────────────
  // Centralized mapping so every status badge uses the same colors.

  /// Returns (foreground, background) for a given item status name.
  static (Color fg, Color bg) badgeColorsForStatus(String status) =>
      switch (status) {
        'open' => (AppColors.success, AppColors.successSurface),
        'pendingVerification' || 'pending' => (
          AppColors.warning,
          AppColors.warningSurface,
        ),
        'verified' => (AppColors.info, AppColors.infoSurface),
        'matched' => (AppColors.primary, AppColors.infoSurface),
        'pendingClaim' => (AppColors.warning, AppColors.warningSurface),
        'claimed' => (AppColors.success, AppColors.successSurface),
        'resolved' => (AppColors.success, AppColors.successSurface),
        'closed' => (AppColors.textTertiary, AppColors.surfaceVariant),
        // Moderation statuses
        'approved' => (AppColors.success, AppColors.successSurface),
        'rejected' => (AppColors.error, AppColors.errorSurface),
        _ => (AppColors.textTertiary, AppColors.surfaceVariant),
      };

  /// Returns (foreground, background) for report-level statuses.
  static (Color fg, Color bg) badgeColorsForReport(String type) =>
      switch (type) {
        'lost' => (AppColors.error, AppColors.errorSurface),
        'found' => (AppColors.success, AppColors.successSurface),
        'matched' => (AppColors.primary, AppColors.infoSurface),
        _ => (AppColors.textTertiary, AppColors.surfaceVariant),
      };
}
