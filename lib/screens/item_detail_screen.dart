import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';

/// Full detail view for a single lost or found item.
///
/// Shows the primary image (with gallery-quality hero animation), item
/// metadata (type, status, location, description, timestamps), and a
/// "storage location" row for found items.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.item});

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final accentSurface =
        isLost ? AppColors.errorSurface : AppColors.successSurface;
    final imageUrl = item.displayUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Image ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null
                  ? Hero(
                      tag: 'item_image_${item.id}',
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
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
            ),
          ),

          // ── Content ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge + Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLost
                                  ? Icons.fmd_bad_rounded
                                  : Icons.inventory_2_rounded,
                              size: 14,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLost ? 'LOST' : 'FOUND',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(status: item.status),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Location
                  if (item.location != null && item.location!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: item.location!,
                    ),

                  // Storage location (found items)
                  if (!isLost &&
                      item.storageLocation != null &&
                      item.storageLocation!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.storefront_outlined,
                      label: 'Stored at: ${item.storageLocation}',
                    ),

                  // Date
                  if (item.createdAt != null)
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: _formatDate(item.createdAt!),
                    ),

                  const SizedBox(height: 20),

                  // Description
                  if (item.description.isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Additional photos
                  if (item.media.length > 1) ...[
                    const Text(
                      'Additional Photos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.media.length - 1,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item.media[index + 1],
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 90,
                                height: 90,
                                color: accentSurface,
                                child: Icon(Icons.broken_image_rounded,
                                    size: 28, color: accent.withValues(alpha: 0.5)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
          size: 64,
          color: accent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
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
      ItemStatus.pendingVerification =>
        ('PENDING', AppColors.warning, AppColors.warningSurface),
      ItemStatus.verified => ('VERIFIED', AppColors.info, AppColors.infoSurface),
      ItemStatus.matched =>
        ('MATCHED', AppColors.primary, AppColors.infoSurface),
      ItemStatus.claimed =>
        ('CLAIMED', AppColors.success, AppColors.successSurface),
      ItemStatus.closed =>
        ('CLOSED', AppColors.textTertiary, AppColors.surfaceVariant),
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

String _formatDate(DateTime date) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = date.hour;
  final m = date.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour12:$m $period';
}
