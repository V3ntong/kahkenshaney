import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ReportStatus { lost, found, matched }

extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
        ReportStatus.lost => 'LOST',
        ReportStatus.found => 'FOUND',
        ReportStatus.matched => 'MATCHED',
      };

  Color get color => switch (this) {
        ReportStatus.lost => AppColors.error,
        ReportStatus.found => AppColors.success,
        ReportStatus.matched => AppColors.primary,
      };

  Color get background => switch (this) {
        ReportStatus.lost => AppColors.errorSurface,
        ReportStatus.found => AppColors.successSurface,
        ReportStatus.matched => AppColors.infoSurface,
      };
}

class ReportItem {
  const ReportItem({
    required this.itemName,
    required this.location,
    required this.timeAgo,
    required this.status,
    required this.icon,
    required this.tint,
  });

  final String itemName;
  final String location;
  final String timeAgo;
  final ReportStatus status;
  final IconData icon;
  final Color tint;
}

class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.report});

  final ReportItem report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: report.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(report.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${report.location} • ${report.timeAgo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: report.status),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
