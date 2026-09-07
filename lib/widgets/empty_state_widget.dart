import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A reusable empty state widget shown when a query returns zero results.
///
/// Provides a consistent icon + message across the app, with an optional
/// CTA button for actions like "Report Lost" / "Report Found".
/// Includes a subtle entrance animation for polish.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accentColor,
    this.ctaLabel,
    this.onCtaTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? accentColor;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.textTertiary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: scale.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: AppTokens.space20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTokens.titleMedium,
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTokens.bodySmall,
              ),
              if (ctaLabel != null && onCtaTap != null) ...[
                const SizedBox(height: AppTokens.space24),
                FilledButton.icon(
                  onPressed: onCtaTap,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(ctaLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A reusable error state widget with retry capability.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppTokens.space20),
            const Text(
              'Something went wrong',
              style: AppTokens.titleMedium,
            ),
            const SizedBox(height: AppTokens.space6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTokens.bodySmall.copyWith(fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.space20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
