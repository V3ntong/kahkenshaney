import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'glass_panel.dart';
import 'status_badge.dart';

/// Reusable grid card for displaying a lost or found item.
///
/// Shows the item image (or a placeholder), name, description, and location.
/// Used in both the Lost and Found 2-column grid layouts.
///
/// [heroTagPrefix] namespaces the Hero tag so the same item rendered in
/// multiple sections (e.g. "Recently Reported" + Lost tab) doesn't cause
/// a duplicate Hero tag collision.
class ItemGridCard extends StatelessWidget {
  const ItemGridCard({
    super.key,
    required this.item,
    this.onTap,
    this.heroTagPrefix = 'item',
  });

  final LostFoundItem item;
  final VoidCallback? onTap;
  final String heroTagPrefix;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final accentSurface = isLost
        ? AppColors.errorSurface
        : AppColors.successSurface;

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
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppTokens.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.media.isNotEmpty
                      ? Hero(
                          tag: '${heroTagPrefix}_${item.id}',
                          child: Image.network(
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
                          ),
                        )
                      : _Placeholder(
                          accent: accent,
                          surface: accentSurface,
                          isLost: isLost,
                        ),
                  Positioned(
                    top: AppTokens.space8,
                    left: AppTokens.space8,
                    child: GlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space8,
                          vertical: AppTokens.space4,
                        ),
                        child: Text(
                          item.category ??
                              (isLost ? 'Lost item' : 'Found item'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.labelTiny.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Details ────────────────────────────────────────
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space12,
                  AppTokens.space10,
                  AppTokens.space12,
                  AppTokens.space12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Item name
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.labelBold,
                    ),

                    // Description (truncated)
                    if (item.description.isNotEmpty)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppTokens.space3),
                          child: Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.bodySmall.copyWith(
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppTokens.space6),

                    // Location + time
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: Text(
                            location.isNotEmpty ? location : 'No location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.labelSmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTokens.space4),

                    // Status pill — pinned to bottom via parent Column max
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: StatusBadge.fromItemStatus(item.status),
                    ),
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
