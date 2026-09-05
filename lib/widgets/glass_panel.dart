import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small, clipped frosted surface intended for image overlays.
///
/// Keep this wrapper limited to overlays rather than wrapping an entire grid
/// card: it bounds the expensive backdrop read to a small area.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.blurSigma = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: dark ? AppColors.glassDarkTint : AppColors.glassLightTint,
              borderRadius: borderRadius,
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F2747),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
