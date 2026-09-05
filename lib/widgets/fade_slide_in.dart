import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable "fadeInDown" entrance animation.
///
/// On first build the child fades from 0→1 opacity while translating from
/// [offset] pixels ABOVE its natural position down to it, over [duration]
/// with an ease-out [curve]. The animation runs ONCE on genuine element
/// entry — it never replays on rebuilds, scroll, or setState — because the
/// state (and its controller) persist for the widget's lifetime.
///
/// Paint-only: [FadeTransition]/[Transform.translate] never block pointer
/// events, so content stays tappable/scrollable from the very first frame.
///
/// Use [staggerDelay] to cascade a finite list of siblings, e.g.
/// `FadeSlideInWidget(delay: FadeSlideInWidget.staggerDelay(i), child: ...)`.
class FadeSlideInWidget extends StatefulWidget {
  const FadeSlideInWidget({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = 28,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;

  /// How long to wait before the animation starts.
  final Duration delay;

  /// Length of the animation itself (spec: ~300–500ms).
  final Duration duration;

  /// Distance in logical pixels the child starts ABOVE its final position.
  final double offset;

  /// Easing applied to both opacity and translation.
  final Curve curve;

  /// Cascading delay for the [index]-th item of a list/grid.
  ///
  /// Each item starts ~[perItemMs] after the previous one, but the total
  /// spread is clamped to [maxSpreadMs] so a 50-item list never makes the
  /// last items wait several seconds — they animate together instead.
  static Duration staggerDelay(
    int index, {
    int perItemMs = 60,
    int maxSpreadMs = 700,
  }) {
    return Duration(milliseconds: math.min(index * perItemMs, maxSpreadMs));
  }

  @override
  State<FadeSlideInWidget> createState() => _FadeSlideInWidgetState();
}

class _FadeSlideInWidgetState extends State<FadeSlideInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _start();
  }

  void _start() {
    // Cancellable Timer (not Future.delayed) so the entrance delay never
    // leaks past the widget's lifetime.
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      // Transform.translate gives a pixel-exact vertical offset (the spec's
      // 20–40px), unlike SlideTransition whose offset is a fraction of the
      // child's own size.
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = widget.curve.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, -widget.offset * (1 - t)),
            child: child,
          );
        },
      ),
    );
  }
}
