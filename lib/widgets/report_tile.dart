import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'status_badge.dart';

enum ReportStatus { lost, found, matched }

extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
        ReportStatus.lost => 'LOST',
        ReportStatus.found => 'FOUND',
        ReportStatus.matched => 'MATCHED',
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
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: report.tint,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(report.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.labelLarge,
                ),
                const SizedBox(height: AppTokens.space3),
                Text(
                  '${report.location} • ${report.timeAgo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          StatusBadge.fromReportType(report.status.name),
        ],
      ),
    );
  }
}
