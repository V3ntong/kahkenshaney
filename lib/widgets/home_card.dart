import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space20),
    this.color = AppColors.surface,
    this.gradient,
    this.onTap,
    this.radius = AppTokens.radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: AppTokens.shadowSm,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          decoration: decoration,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
