import 'package:flutter/material.dart';

import 'animation_constants.dart';

// ─── Fade Through ──────────────────────────────────────────────────────
/// Material Design 3 "Fade Through" transition.
///
/// The outgoing page fades out while the incoming page fades in and slides
/// up slightly.  Used when navigating between unrelated sections
/// (e.g. auth → dashboard, login → landing).
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AnimationConstants.kSlow,
          reverseTransitionDuration: AnimationConstants.kNormal,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduced =
                AnimationConstants.shouldReduceMotion(context);
            if (reduced) return child;

            final curve = CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.kStandard,
              reverseCurve: AnimationConstants.kAccelerate,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
}

// ─── Shared Axis (Horizontal) ─────────────────────────────────────────
/// Material Design 3 "Shared Axis" transition (horizontal axis).
///
/// The outgoing page slides out to the left while fading; the incoming page
/// slides in from the right while fading.  Used for sequential, peer-level
/// screens (e.g. Login → Forgot Password → OTP → Reset Password).
class SharedAxisRoute<T> extends PageRouteBuilder<T> {
  SharedAxisRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AnimationConstants.kNormal,
          reverseTransitionDuration: AnimationConstants.kNormal,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduced =
                AnimationConstants.shouldReduceMotion(context);
            if (reduced) return child;

            final curve = CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.kStandard,
              reverseCurve: AnimationConstants.kStandard,
            );

            final incomingSlide = Tween<Offset>(
              begin: const Offset(0.3, 0.0),
              end: Offset.zero,
            ).animate(curve);

            final incomingFade =
                Tween<double>(begin: 0.0, end: 1.0).animate(curve);

            return FadeTransition(
              opacity: incomingFade,
              child: SlideTransition(
                position: incomingSlide,
                child: child,
              ),
            );
          },
        );
}

// ─── Fade Slide (Up) ──────────────────────────────────────────────────
/// The incoming page fades in while sliding up from a slight offset below.
/// Used for forward-progression pushes (e.g. Landing → Login) and modal
/// overlays (e.g. Terms & Conditions).
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  FadeSlideRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AnimationConstants.kNormal,
          reverseTransitionDuration: AnimationConstants.kFast,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduced =
                AnimationConstants.shouldReduceMotion(context);
            if (reduced) return child;

            final curve = CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.kStandard,
              reverseCurve: AnimationConstants.kAccelerate,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
}

// ─── Scale Fade ───────────────────────────────────────────────────────
/// The incoming page scales up from 0.95 while fading in.
/// Used for dialogs, bottom sheets, and overlay-style screens.
class ScaleFadeRoute<T> extends PageRouteBuilder<T> {
  ScaleFadeRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AnimationConstants.kNormal,
          reverseTransitionDuration: AnimationConstants.kFast,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduced =
                AnimationConstants.shouldReduceMotion(context);
            if (reduced) return child;

            final curve = CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.kStandard,
              reverseCurve: AnimationConstants.kAccelerate,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}

// ─── No Transition ────────────────────────────────────────────────────
/// Instant replacement with no animation.
/// Used only when explicitly required (e.g. error screen retry).
class NoTransitionRoute<T> extends PageRouteBuilder<T> {
  NoTransitionRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        );
}
