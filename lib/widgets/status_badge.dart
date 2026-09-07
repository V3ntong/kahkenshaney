import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A consistent, reusable status badge used across the entire app.
///
/// Replaces the 7+ inline `_StatusBadge` / `_StatusPill` implementations
/// scattered across screens and widgets.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    this.size = StatusBadgeSize.small,
  });

  /// Factory that creates a badge from an [ItemStatus].
  factory StatusBadge.fromItemStatus(
    ItemStatus status, {
    StatusBadgeSize size = StatusBadgeSize.small,
  }) {
    final (fg, bg) = AppTokens.badgeColorsForStatus(status.name);
    return StatusBadge(
      label: status.label,
      foregroundColor: fg,
      backgroundColor: bg,
      size: size,
    );
  }

  /// Factory that creates a badge from a report type string.
  factory StatusBadge.fromReportType(
    String type, {
    StatusBadgeSize size = StatusBadgeSize.small,
  }) {
    final (fg, bg) = AppTokens.badgeColorsForReport(type);
    return StatusBadge(
      label: type.toUpperCase(),
      foregroundColor: fg,
      backgroundColor: bg,
      size: size,
    );
  }

  /// Factory that creates a badge from a moderation status string.
  factory StatusBadge.fromModerationStatus(
    String status, {
    StatusBadgeSize size = StatusBadgeSize.small,
  }) {
    final (fg, bg) = AppTokens.badgeColorsForStatus(status);
    return StatusBadge(
      label: status.toUpperCase(),
      foregroundColor: fg,
      backgroundColor: bg,
      size: size,
    );
  }

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final (fontSize, hPad, vPad, iconSize) = switch (size) {
      StatusBadgeSize.tiny => (10.0, 6.0, 2.0, 12.0),
      StatusBadgeSize.small => (11.0, 8.0, 3.0, 14.0),
      StatusBadgeSize.medium => (12.0, 10.0, 5.0, 16.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: foregroundColor,
        ),
      ),
    );
  }
}

enum StatusBadgeSize { tiny, small, medium }

/// A kind badge (LOST / FOUND) with icon, used on cards and detail screens.
class KindBadge extends StatelessWidget {
  const KindBadge({
    super.key,
    required this.isLost,
    this.size = StatusBadgeSize.small,
  });

  final bool isLost;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final (fontSize, hPad, vPad, iconSize) = switch (size) {
      StatusBadgeSize.tiny => (10.0, 6.0, 2.0, 12.0),
      StatusBadgeSize.small => (11.0, 8.0, 3.0, 14.0),
      StatusBadgeSize.medium => (12.0, 10.0, 5.0, 16.0),
    };

    final fg = isLost ? AppColors.error : AppColors.success;
    final bg = isLost ? AppColors.errorSurface : AppColors.successSurface;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLost ? Icons.fmd_bad_rounded : Icons.inventory_2_rounded,
            size: iconSize,
            color: fg,
          ),
          SizedBox(width: AppTokens.space3),
          Text(
            isLost ? 'LOST' : 'FOUND',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
