import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/status_tracker_widget.dart';

/// User's "My Reports" screen — shows all items they submitted
/// with status badges and a full status tracker on tap.
class UserReportsScreen extends StatefulWidget {
  const UserReportsScreen({
    super.key,
    required this.ownerUid,
    this.repository,
  });

  final String ownerUid;
  final ItemRepository? repository;

  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  late final ItemRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ItemRepository();
  }

  void _showItemDetail(LostFoundItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Reports')),
      body: StreamBuilder<List<LostFoundItem>>(
        stream: _repo.streamUserItems(widget.ownerUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data ?? const <LostFoundItem>[];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No reports yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Items you report will appear here.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ReportCard(
                item: item,
                onTap: () => _showItemDetail(item),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item, required this.onTap});

  final LostFoundItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: item.displayUrl != null
                    ? Image.network(item.displayUrl!, fit: BoxFit.cover)
                    : Container(
                        color: accent.withValues(alpha: 0.1),
                        child: Icon(
                          isLost ? Icons.fmd_bad_rounded : Icons.inventory_2_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 4),
                  StatusTrackerWidget(
                    currentStatus: item.status,
                    compact: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Moderation status badge
            Flexible(child: _ModerationBadge(status: item.moderationStatus)),
          ],
        ),
      ),
    );
  }
}

// ── Moderation Badge ──────────────────────────────────────────────────────

class _ModerationBadge extends StatelessWidget {
  const _ModerationBadge({required this.status});

  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ModerationStatus.pending => (AppColors.warning, 'Pending'),
      ModerationStatus.approved => (AppColors.success, 'Approved'),
      ModerationStatus.rejected => (AppColors.error, 'Rejected'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Item Detail Sheet ─────────────────────────────────────────────────────

class _ItemDetailSheet extends StatelessWidget {
  const _ItemDetailSheet({required this.item});

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image
              if (item.displayUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    item.displayUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),

              // Title + Kind badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  _ModerationBadge(status: item.moderationStatus),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLost ? 'LOST' : 'FOUND',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent),
                ),
              ),

              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],

              if (item.location != null && item.location!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(item.location!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ],

              // Status Tracker
              const SizedBox(height: 20),
              const Text('Status Tracker', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              StatusTrackerWidget(
                currentStatus: item.status,
                statusHistory: item.statusHistory,
              ),
            ],
          ),
        );
      },
    );
  }
}
