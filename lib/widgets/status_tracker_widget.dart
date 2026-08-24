import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';

/// A horizontal stepper UI showing the item status pipeline:
/// Submitted → Pending Verification → Verified → Matched → Claimed → Archived
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
    ItemStatus.claimed,
    ItemStatus.closed,
  ];

  static const _icons = [
    Icons.assignment_turned_in_rounded,
    Icons.pending_actions_rounded,
    Icons.verified_rounded,
    Icons.swap_horiz_rounded,
    Icons.check_circle_outline_rounded,
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
        const SizedBox(height: 12),
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
          final isFuture = index > currentIndex;

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
                const SizedBox(height: 6),
                // Label
                Text(
                  status.shortLabel,
                  textAlign: TextAlign.center,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(currentStatus).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icons[currentIndex],
            size: 14,
            color: _statusColor(currentStatus),
          ),
          const SizedBox(width: 6),
          Text(
            currentStatus.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _statusColor(currentStatus),
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
        const Text(
          'Status History',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        ...statusHistory.reversed.map((entry) {
          final status = ItemStatusX.fromFirestore(entry.status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status),
                  ),
                ),
                if (entry.changedAt != null) ...[
                  const SizedBox(width: 8),
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

  Color _statusColor(ItemStatus status) => switch (status) {
        ItemStatus.open => AppColors.info,
        ItemStatus.pendingVerification => AppColors.warning,
        ItemStatus.verified => AppColors.success,
        ItemStatus.matched => AppColors.primary,
        ItemStatus.claimed => AppColors.success,
        ItemStatus.closed => AppColors.textTertiary,
      };

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
