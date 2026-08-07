import 'package:flutter/material.dart';

import '../utils/animation_constants.dart';

/// Animates a whole number from 0 up to [value] using an easing curve.
///
/// Uses [TweenAnimationBuilder] so the animation runs once when the widget
/// first appears and again whenever [value] changes. Respects the platform's
/// "reduce motion" setting by jumping straight to the target.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 900),
    this.style,
    this.semanticsLabel,
  });

  final int value;
  final Duration duration;
  final TextStyle? style;

  /// Accessible label, e.g. "12 items recovered". Defaults to the number.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final end = value.toDouble();

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: end),
          duration: reduceMotion ? Duration.zero : duration,
          curve: AnimationConstants.kDecelerate,
          builder: (context, value, _) {
            return Text(
              value.round().toString(),
              style: style,
            );
          },
        ),
      ),
    );
  }
}
