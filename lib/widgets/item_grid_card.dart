import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';

/// Reusable grid card for displaying a lost or found item.
///
/// Shows the item image (or a placeholder), name, description, and location.
/// Used in both the Lost and Found 2-column grid layouts.
class ItemGridCard extends StatelessWidget {
  const ItemGridCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final LostFoundItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final accentSurface = isLost ? AppColors.errorSurface : AppColors.successSurface;

    final location = item.location?.isNotEmpty == true
        ? item.location!
        : item.storageLocation?.isNotEmpty == true
            ? item.storageLocation!
            : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: item.media.isNotEmpty
                  ? Image.network(
                      item.media.first,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: accentSurface,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => _Placeholder(
                        accent: accent,
                        surface: accentSurface,
                        isLost: isLost,
                      ),
                    )
                  : _Placeholder(
                      accent: accent,
                      surface: accentSurface,
                      isLost: isLost,
                    ),
            ),

            // ── Details ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Item name
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    // Description (truncated)
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Flexible(
                        child: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Location + time
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location.isNotEmpty ? location : 'No location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Status pill
                    _StatusPill(status: item.status),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.accent,
    required this.surface,
    required this.isLost,
  });

  final Color accent;
  final Color surface;
  final bool isLost;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surface,
      child: Center(
        child: Icon(
          isLost ? Icons.fmd_bad_rounded : Icons.inventory_2_rounded,
          size: 40,
          color: accent.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      ItemStatus.open => ('OPEN', AppColors.success, AppColors.successSurface),
      ItemStatus.pendingVerification => ('PENDING', AppColors.warning, AppColors.warningSurface),
      ItemStatus.verified => ('VERIFIED', AppColors.info, AppColors.infoSurface),
      ItemStatus.matched => ('MATCHED', AppColors.primary, AppColors.infoSurface),
      ItemStatus.claimed => ('CLAIMED', AppColors.success, AppColors.successSurface),
      ItemStatus.closed => ('CLOSED', AppColors.textTertiary, AppColors.surfaceVariant),
      ItemStatus.resolved => ('RESOLVED', AppColors.success, AppColors.successSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
