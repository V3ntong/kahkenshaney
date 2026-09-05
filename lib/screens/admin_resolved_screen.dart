import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../data/firestore/notification_service.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Admin screen — shows all non-terminal approved items.
/// Admins can mark items as Resolved directly from here.
class AdminResolvedScreen extends StatefulWidget {
  const AdminResolvedScreen({
    super.key,
    required this.adminUid,
    this.repository,
  });

  final String adminUid;
  final ItemRepository? repository;

  @override
  State<AdminResolvedScreen> createState() => _AdminResolvedScreenState();
}

class _AdminResolvedScreenState extends State<AdminResolvedScreen> {
  late final ItemRepository _repo;
  late final NotificationService _notifService;
  List<LostFoundItem>? _localItems;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ItemRepository();
    _notifService = NotificationService();
  }

  Future<void> _markResolved(LostFoundItem item) async {
    // Instantly remove from local list
    if (_localItems != null) {
      setState(() {
        _localItems = _localItems!..removeWhere((i) => i.id == item.id);
      });
    }

    final history = List<Map<String, dynamic>>.from(
      item.statusHistory.map((e) => e.toMap()),
    );
    history.add({
      'status': ItemStatus.resolved.firestoreValue,
      'changedAt': DateTime.now(),
      'changedBy': widget.adminUid,
    });

    await _repo.updateItemFields(item.id, {
      'status': ItemStatus.resolved.firestoreValue,
      'statusHistory': history,
    });
    await _notifService.notifyStatusChange(
      item: item,
      newStatus: ItemStatus.resolved,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item marked as resolved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<LostFoundItem>>(
        stream: _repo.streamNonTerminalItems(),
        builder: (context, snapshot) {
          // Sync local list from stream
          if (snapshot.hasData && _localItems == null) {
            _localItems = snapshot.data;
          } else if (snapshot.hasData && _localItems != null) {
            final streamIds = snapshot.data!.map((i) => i.id).toSet();
            // Remove items from local that no longer exist in stream
            _localItems = _localItems!
                .where((i) => streamIds.contains(i.id))
                .toList();
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              _localItems == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 44, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final items = _localItems ?? snapshot.data ?? const <LostFoundItem>[];

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
                    child: const Icon(Icons.verified_rounded,
                        size: 36, color: AppColors.success),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All resolved!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No pending items to resolve.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
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
              return _ResolvedCard(
                item: item,
                onResolve: () => _markResolved(item),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Resolved Card ────────────────────────────────────────────────────────

class _ResolvedCard extends StatelessWidget {
  const _ResolvedCard({
    required this.item,
    required this.onResolve,
  });

  final LostFoundItem item;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;

    return Container(
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
                            isLost
                                ? Icons.fmd_bad_rounded
                                : Icons.inventory_2_rounded,
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
                      style: TextStyle(
                          fontSize: 12,
                          color: accent,
                          fontWeight: FontWeight.w600),
                    ),
                    if (item.location != null && item.location!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(item.createdAt!),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status + Action
          Row(
            children: [
              // Current status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.shortLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(item.status),
                  ),
                ),
              ),
              const Spacer(),
              // Mark as Resolved button
              GestureDetector(
                onTap: onResolve,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 16, color: AppColors.accent),
                      SizedBox(width: 4),
                      Text(
                        'Mark Resolved',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.open:
        return AppColors.primary;
      case ItemStatus.pendingVerification:
        return AppColors.warning;
      case ItemStatus.verified:
        return AppColors.success;
      case ItemStatus.matched:
        return AppColors.primary;
      case ItemStatus.pendingClaim:
        return AppColors.warning;
      case ItemStatus.claimed:
        return AppColors.success;
      case ItemStatus.resolved:
        return AppColors.accent;
      case ItemStatus.closed:
        return AppColors.textTertiary;
    }
  }

  String _formatDate(DateTime date) {
    final h = date.hour;
    final m = date.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${_monthAbbr[date.month - 1]} ${date.day}, ${date.year}  $hour12:$m $period';
  }
}
