import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'count_up.dart';
import 'pill_button.dart';

/// Featured hero card with a large animated value, status chip, and two
/// primary action pills. Uses the brand gradient and soft, airy spacing.
class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueUnit,
    required this.subtitle,
    this.trend = '+18% this week',
    this.onReportLost,
    this.onReportFound,
    this.onViewAll,
  });

  /// Small caption above the big number, e.g. "THIS MONTH".
  final String label;

  /// The large highlighted number.
  final int value;

  /// Unit / suffix shown after the number, e.g. "items".
  final String valueUnit;

  final String subtitle;
  final String trend;
  final VoidCallback? onReportLost;
  final VoidCallback? onReportFound;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TrendChip(text: trend),
            ],
          ),
          const SizedBox(height: 16),
          _BigValue(value: value, unit: valueUnit),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Report Lost',
                  icon: Icons.fmd_bad_rounded,
                  background: Colors.white,
                  foreground: AppColors.primary,
                  expanded: true,
                  onPressed: onReportLost,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  label: 'Report Found',
                  icon: Icons.check_circle_outline_rounded,
                  background: Colors.white.withValues(alpha: 0.16),
                  foreground: Colors.white,
                  borderColor: Colors.white.withValues(alpha: 0.45),
                  expanded: true,
                  onPressed: onReportFound,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.trending_up_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      textBaseline: TextBaseline.alphabetic,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      children: [
        CountUp(
          value: value,
          semanticsLabel: '$value $unit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unit,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}