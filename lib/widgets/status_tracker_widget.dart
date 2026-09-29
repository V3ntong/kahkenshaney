import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A horizontal stepper UI showing the item status pipeline:
/// Submitted → Pending Verification → Verified → Matched → Pending Claim →
/// Claimed → Resolved → Archived
///
/// Highlights the current step and greys out future ones.
/// Derives progress from [statusHistory] when available, falls back to
/// [currentStatus]. Shows rejected state clearly.
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

  /// Labels for each pipeline step - full labels for horizontal scrolling
  static const _labels = [
    'Submitted',
    'Pending Verification',
    'Verified',
    'Matched',
    'Pending Claim',
    'Claimed',
    'Resolved',
    'Archived',
  ];

  /// Short labels for compact mode
  static const _shortLabels = [
    'Submitted',
    'Pending',
    'Verified',
    'Matched',
    'Claim Pending',
    'Claimed',
    'Resolved',
    'Archived',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateCurrentIndex();

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

  /// Calculate the current pipeline index from statusHistory when available,
  /// otherwise fall back to currentStatus index.
  /// Rejected items show a special rejected state (index = -1).
  int _calculateCurrentIndex() {
    // Check if item was rejected (moderation rejected)
    final hasRejection = statusHistory.any(
      (e) =>
          e.status == ModerationStatus.rejected.name || e.status == 'rejected',
    );
    if (hasRejection) return -1;

    if (statusHistory.isEmpty) {
      return _pipeline.indexOf(currentStatus);
    }

    // Find the latest status in history that's in our pipeline
    for (var i = statusHistory.length - 1; i >= 0; i--) {
      final entry = statusHistory[i];
      final idx = _pipeline.indexWhere((s) => s.name == entry.status);
      if (idx != -1) return idx;
    }

    // Fallback to currentStatus
    return _pipeline.indexOf(currentStatus);
  }

  Widget _buildStepper(int currentIndex) {
    final isRejected = currentIndex == -1;

    return SizedBox(
      height: isRejected ? 100 : 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: List.generate(_pipeline.length, (index) {
            final isDone = index < currentIndex && currentIndex != -1;
            final isCurrent = index == currentIndex && currentIndex != -1;

            return _StepNode(
              index: index,
              label: _labels[index],
              shortLabel: _shortLabels[index],
              icon: _icons[index],
              isDone: isDone,
              isCurrent: isCurrent,
              isRejected: isRejected,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCompact(int currentIndex) {
    final isRejected = currentIndex == -1;
    if (isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space10,
          vertical: AppTokens.space6,
        ),
        decoration: BoxDecoration(
          color: AppColors.errorSurface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_rounded, size: 14, color: AppColors.error),
            const SizedBox(width: AppTokens.space6),
            Flexible(
              child: Text(
                'Rejected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
          // Flexible keeps the chip inside narrow cards (report rows) and at
          // large text scales instead of overflowing the parent Row.
          Flexible(
            child: Text(
              currentStatus.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
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
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.isDone,
    required this.isCurrent,
    required this.isRejected,
  });

  final int index;
  final String label;
  final String shortLabel;
  final IconData icon;
  final bool isDone;
  final bool isCurrent;
  final bool isRejected;

  @override
  Widget build(BuildContext context) {
    // Determine colors based on state
    Color nodeColor;
    Color iconColor;
    Color labelColor;
    FontWeight labelWeight;
    IconData displayIcon;

    if (isRejected) {
      nodeColor = AppColors.surfaceVariant;
      iconColor = AppColors.textTertiary;
      labelColor = AppColors.textTertiary;
      labelWeight = FontWeight.w500;
      displayIcon = icon;
    } else if (isDone) {
      nodeColor = AppColors.success;
      iconColor = Colors.white;
      labelColor = AppColors.success;
      labelWeight = FontWeight.w700;
      displayIcon = Icons.check_rounded;
    } else if (isCurrent) {
      nodeColor = AppColors.primary;
      iconColor = Colors.white;
      labelColor = AppColors.primary;
      labelWeight = FontWeight.w700;
      displayIcon = icon;
    } else {
      nodeColor = AppColors.surfaceVariant;
      iconColor = AppColors.textTertiary;
      labelColor = AppColors.textTertiary;
      labelWeight = FontWeight.w500;
      displayIcon = icon;
    }

    return SizedBox(
      width: 110, // Fixed width per step for horizontal scrolling
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon circle with connector line
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Connector line (before this node, except first)
              if (index > 0)
                Positioned(
                  top: 18,
                  left: -28,
                  width: 28,
                  child: Container(
                    height: 2,
                    color: isDone ? AppColors.success : AppColors.cardBorder,
                  ),
                ),
              // Node circle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone
                        ? AppColors.success
                        : isCurrent
                        ? AppColors.primary
                        : isRejected
                        ? AppColors.error.withValues(alpha: 0.5)
                        : AppColors.cardBorder,
                    width: isCurrent || isDone ? 2 : 1.5,
                  ),
                ),
                child: Icon(displayIcon, size: 18, color: iconColor),
              ),
              // Pulse animation for current step
              if (isCurrent)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Label - full label, horizontally scrollable if needed
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: labelWeight,
                color: labelColor,
                height: 1.2,
              ),
            ),
          ),
          // Rejected indicator
          if (isRejected && index == 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Rejected',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
