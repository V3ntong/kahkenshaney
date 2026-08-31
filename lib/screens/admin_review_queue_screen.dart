import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../data/firestore/notification_service.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/status_tracker_widget.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Admin review queue — lists all pending items with approve/reject/status controls.
class AdminReviewQueueScreen extends StatefulWidget {
  const AdminReviewQueueScreen({
    super.key,
    required this.adminUid,
    this.repository,
  });

  final String adminUid;
  final ItemRepository? repository;

  @override
  State<AdminReviewQueueScreen> createState() => _AdminReviewQueueScreenState();
}

class _AdminReviewQueueScreenState extends State<AdminReviewQueueScreen> {
  late final ItemRepository _repo;
  late final NotificationService _notifService;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ItemRepository();
    _notifService = NotificationService();
  }

  Future<void> _updateModeration(
      LostFoundItem item, ModerationStatus status) async {
    await _repo.updateItemFields(item.id, {
      'moderationStatus': status.firestoreValue,
    });
    await _notifService.notifyModerationChange(item: item, newStatus: status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item ${status.name}')),
    );
  }

  Future<void> _updateItemStatus(
      LostFoundItem item, ItemStatus newStatus, {String? matchedItemId}) async {
    final history = List<Map<String, dynamic>>.from(
      item.statusHistory.map((e) => e.toMap()),
    );
    history.add({
      'status': newStatus.firestoreValue,
      'changedAt': DateTime.now(),
      'changedBy': widget.adminUid,
    });

    final updates = <String, dynamic>{
      'status': newStatus.firestoreValue,
      'statusHistory': history,
    };
    if (matchedItemId != null) updates['matchedItemId'] = matchedItemId;

    await _repo.updateItemFields(item.id, updates);
    await _notifService.notifyStatusChange(item: item, newStatus: newStatus);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to ${newStatus.label}')),
    );
  }

  void _showItemDetail(LostFoundItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemDetailSheet(
        item: item,
        adminUid: widget.adminUid,
        onModerate: (status) => _updateModeration(item, status),
        onStatusChange: (status) => _updateItemStatus(item, status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<LostFoundItem>>(
        stream: _repo.streamPendingItems(),
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
                      color: AppColors.successSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 36, color: AppColors.success),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No pending items to review.',
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
              return _ReviewCard(
                item: item,
                onTap: () => _showItemDetail(item),
                onApprove: () => _updateModeration(item, ModerationStatus.approved),
                onReject: () => _updateModeration(item, ModerationStatus.rejected),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Review Card ───────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  final LostFoundItem item;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      const SizedBox(height: 2),
                      Text(
                        isLost ? 'Lost Item' : 'Found Item',
                        style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                      ),
                      if (item.location != null && item.location!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                      if (item.createdAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.createdAt!),
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionChip(
                    label: 'Approve',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionChip(
                    label: 'Reject',
                    icon: Icons.cancel_rounded,
                    color: AppColors.error,
                    onTap: onReject,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final h = date.hour;
    final m = date.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${_monthAbbr[date.month - 1]} ${date.day}, ${date.year}  $hour12:$m $period';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item Detail Sheet ─────────────────────────────────────────────────────

class _ItemDetailSheet extends StatelessWidget {
  const _ItemDetailSheet({
    required this.item,
    required this.adminUid,
    required this.onModerate,
    required this.onStatusChange,
  });

  final LostFoundItem item;
  final String adminUid;
  final ValueChanged<ModerationStatus> onModerate;
  final ValueChanged<ItemStatus> onStatusChange;

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
              // Handle
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

              // Title + Kind
              Text(
                item.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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

              // Lifecycle status actions
              const SizedBox(height: 20),
              const Text('Update Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.status == ItemStatus.open)
                    _StatusButton(label: 'Pending Verification', color: AppColors.warning, onTap: () => onStatusChange(ItemStatus.pendingVerification)),
                  if (item.status == ItemStatus.pendingVerification)
                    _StatusButton(label: 'Verified', color: AppColors.success, onTap: () => onStatusChange(ItemStatus.verified)),
                  if (item.status == ItemStatus.verified)
                    _StatusButton(label: 'Matched', color: AppColors.primary, onTap: () => onStatusChange(ItemStatus.matched)),
                  if (item.status == ItemStatus.matched)
                    _StatusButton(label: 'Claimed', color: AppColors.success, onTap: () => onStatusChange(ItemStatus.claimed)),
                  if (item.status == ItemStatus.claimed)
                    _StatusButton(label: 'Archived', color: AppColors.textTertiary, onTap: () => onStatusChange(ItemStatus.closed)),
                ],
              ),

              // Moderation actions
              const SizedBox(height: 20),
              const Text('Moderation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatusButton(
                      label: 'Approve',
                      color: AppColors.success,
                      onTap: () => onModerate(ModerationStatus.approved),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusButton(
                      label: 'Reject',
                      color: AppColors.error,
                      onTap: () => onModerate(ModerationStatus.rejected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
