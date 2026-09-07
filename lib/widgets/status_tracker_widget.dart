import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A horizontal stepper UI showing the item status pipeline:
/// Submitted → Pending Verification → Verified → Matched → Pending Claim →
/// Claimed → Resolved → Archived
///
/// Highlights the current step and greys out future ones.
class StatusTrackerWidget extends StatelessWidget {
  const StatusTrackerWidget({
    super.key,
    required this.currentStatus,
    this.statusHistory = const [],
    this.compact = false,
  });

  final ItemStatus currentStatus;
  final List<StatusHistoryEntry> statusHistory;
  final bool compact;

  static const _pipeline = [
    ItemStatus.open,
    ItemStatus.pendingVerification,
    ItemStatus.verified,
    ItemStatus.matched,
    ItemStatus.pendingClaim,
    ItemStatus.claimed,
    ItemStatus.resolved,
    ItemStatus.closed,
  ];

  static const _icons = [
    Icons.assignment_turned_in_rounded,
    Icons.pending_actions_rounded,
    Icons.verified_rounded,
    Icons.swap_horiz_rounded,
    Icons.how_to_reg_rounded,
    Icons.check_circle_outline_rounded,
    Icons.task_alt_rounded,
    Icons.archive_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _pipeline.indexOf(currentStatus);

    if (compact) return _buildCompact(currentIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepper(currentIndex),
        const SizedBox(height: AppTokens.space12),
        _buildHistory(),
      ],
    );
  }

  Widget _buildStepper(int currentIndex) {
    return SizedBox(
      height: 80,
      child: Row(
        children: List.generate(_pipeline.length, (index) {
          final status = _pipeline[index];
          final isDone = index < currentIndex;
          final isCurrent = index == currentIndex;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? AppColors.success
                          : isCurrent
                              ? AppColors.primary
                              : AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : _icons[index],
                    size: 18,
                    color: isDone || isCurrent
                        ? Colors.white
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppTokens.space6),
                // Label
                Text(
                  status.shortLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isDone
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.primary
                            : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCompact(int currentIndex) {
    final (fg, bg) = AppTokens.badgeColorsForStatus(
      _pipeline[currentIndex].name,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icons[currentIndex], size: 14, color: fg),
          const SizedBox(width: AppTokens.space6),
          Text(
            currentStatus.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (statusHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status History', style: AppTokens.labelSmall),
        const SizedBox(height: AppTokens.space6),
        ...statusHistory.reversed.map((entry) {
          final status = ItemStatusX.fromFirestore(entry.status);
          final (fg, _) = AppTokens.badgeColorsForStatus(status.name);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: fg,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (entry.changedAt != null) ...[
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    _formatDate(entry.changedAt!),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
