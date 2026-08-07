import 'package:flutter/material.dart';

/// Shared animation durations and curves used across the application.
///
/// Follows Material Design 3 motion guidelines for consistent, polished
/// transitions on every platform.
abstract final class AnimationConstants {
  // ── Durations ──────────────────────────────────────────────────────

  /// Fast transitions: micro-interactions, icon scaling, opacity changes.
  static const Duration kFast = Duration(milliseconds: 200);

  /// Normal transitions: page transitions, tab switches, expand/collapse.
  static const Duration kNormal = Duration(milliseconds: 300);

  /// Slow transitions: large overlays, shared-axis page transitions.
  static const Duration kSlow = Duration(milliseconds: 350);

  // ── Curves ─────────────────────────────────────────────────────────

  /// Standard deceleration curve for elements entering the screen.
  static const Curve kDecelerate = Curves.easeOutCubic;

  /// Curve for elements leaving the screen.
  static const Curve kAccelerate = Curves.easeInCubic;

  /// Standard combined enter/exit curve (used for page transitions).
  static const Curve kStandard = Curves.easeOutCubic;

  /// Spring-like curve for playful micro-interactions.
  static const Curve kBounce = Curves.easeOutBack;

  // ── Accessibility ──────────────────────────────────────────────────

  /// Returns `true` when the user has enabled "Reduce motion" in their
  /// device accessibility settings.  When `true`, page transitions should
  /// use instant (zero-duration) replacements instead of animations.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }
}
