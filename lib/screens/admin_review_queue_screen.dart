import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../data/firestore/notification_service.dart';
import '../models/item_claim.dart';
import '../models/lost_found_item.dart';
import '../services/claim_api.dart';
import '../theme/app_theme.dart';
import '../widgets/action_progress_bar.dart';
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
  List<LostFoundItem>? _localItems;
  final _actionController = ActionController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ItemRepository();
    _notifService = NotificationService();
  }

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _updateModeration(
      LostFoundItem item, ModerationStatus status, {String? reason}) async {
    if (_localItems != null) {
      setState(() {
        _localItems = _localItems!..removeWhere((i) => i.id == item.id);
      });
    }
    _actionController.setInProgress();
    final updates = <String, dynamic>{
      'moderationStatus': status.firestoreValue,
    };
    if (reason != null && reason.isNotEmpty) {
      updates['rejectionReason'] = reason;
    }
    try {
      await _repo.updateItemFields(item.id, updates);
      await _notifService.notifyModerationChange(item: item, newStatus: status);
      if (!mounted) return;
      _actionController.setSuccess(message: 'Item ${status.name}');
    } catch (e) {
      if (!mounted) return;
      _actionController.setError('Failed: ${e.toString()}');
    }
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

    if (newStatus == ItemStatus.resolved && _localItems != null) {
      setState(() {
        _localItems = _localItems!..removeWhere((i) => i.id == item.id);
      });
    }

    _actionController.setInProgress();
    final updates = <String, dynamic>{
      'status': newStatus.firestoreValue,
      'statusHistory': history,
    };
    if (matchedItemId != null) updates['matchedItemId'] = matchedItemId;

    // When resolving, store the admin who resolved and the timestamp.
    if (newStatus == ItemStatus.resolved) {
      updates['resolvedByAdminId'] = widget.adminUid;
      updates['resolvedAt'] = DateTime.now();
    }

    try {
      await _repo.updateItemFields(item.id, updates);
      await _notifService.notifyStatusChange(item: item, newStatus: newStatus);
      if (!mounted) return;
      _actionController.setSuccess(message: 'Status updated to ${newStatus.label}');
    } catch (e) {
      if (!mounted) return;
      _actionController.setError('Failed: ${e.toString()}');
    }
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
        onModerate: (status, {reason}) async {
          await _updateModeration(item, status, reason: reason);
          if (mounted) Navigator.of(context).pop();
        },
        onStatusChange: (status) => _updateItemStatus(item, status),
        onApproveClaim: (claim) => _approveClaim(item, claim),
      ),
    );
  }

  /// A4: admin approves one submitted claim — the server rejects the other
  /// open claims and resolves the item in favor of [claim].
  Future<void> _approveClaim(LostFoundItem item, ItemClaim claim) async {
    final claimer = (claim.claimerName != null &&
            claim.claimerName!.trim().isNotEmpty)
        ? claim.claimerName!
        : 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Claim'),
        content: Text(
          'Approve the claim by $claimer? All other claims on '
          '"${item.title}" will be rejected and the item will be marked '
          'resolved.',
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _actionController.setInProgress();
    try {
      await ClaimApi().approveClaim(item.id, claim.id);
      if (_localItems != null) {
        setState(() {
          _localItems = _localItems!..removeWhere((i) => i.id == item.id);
        });
      }
      if (!mounted) return;
      _actionController.setSuccess(message: 'Claim approved');
      Navigator.of(context).pop();
    } on ClaimApiException catch (e) {
      if (!mounted) return;
      _actionController.setError(e.message);
    } catch (e) {
      if (!mounted) return;
      _actionController.setError('Failed: ${e.toString()}');
    }
  }

  void _showRejectDialog(LostFoundItem item) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a reason for rejecting this item. The reporter will be notified.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Incomplete information, duplicate report...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.6),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateModeration(item, ModerationStatus.rejected,
                  reason: reasonCtrl.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          StreamBuilder<List<LostFoundItem>>(
            stream: _repo.streamPendingItems(),
            builder: (context, snapshot) {
              if (snapshot.hasData && _localItems == null) {
                _localItems = snapshot.data;
              } else if (snapshot.hasData && snapshot.data!.length != _localItems!.length) {
                final streamIds = snapshot.data!.map((i) => i.id).toSet();
                final localIds = _localItems!.map((i) => i.id).toSet();
                final newFromStream = snapshot.data!
                    .where((i) => !localIds.contains(i.id))
                    .toList();
                if (newFromStream.isNotEmpty) {
                  _localItems = [...newFromStream, ..._localItems!];
                }
                _localItems = _localItems!
                    .where((i) => streamIds.contains(i.id))
                    .toList();
              }

              if (snapshot.connectionState == ConnectionState.waiting && _localItems == null) {
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

              // B8: group the queue into nested "Found Review" and
              // "Lost Review" sub-sections (still one Review Queue screen).
              final children = <Widget>[];
              void addSection(String title, ItemKind kind, Color color) {
                final group =
                    items.where((i) => i.kind == kind).toList();
                if (group.isEmpty) return;
                if (children.isNotEmpty) {
                  children.add(const SizedBox(height: 20));
                }
                children.add(_QueueSectionHeader(
                  title: title,
                  count: group.length,
                  color: color,
                ));
                children.add(const SizedBox(height: 12));
                for (var i = 0; i < group.length; i++) {
                  final item = group[i];
                  children.add(Padding(
                    padding: EdgeInsets.only(
                      bottom: i == group.length - 1 ? 0 : 12,
                    ),
                    child: _ReviewCard(
                      item: item,
                      onTap: () => _showItemDetail(item),
                      onApprove: () =>
                          _updateModeration(item, ModerationStatus.approved),
                      onReject: () => _showRejectDialog(item),
                    ),
                  ));
                }
              }

              addSection('Found Review', ItemKind.found, AppColors.success);
              addSection('Lost Review', ItemKind.lost, AppColors.error);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: _actionController,
              builder: (context, _) => ActionProgressBar(
                state: _actionController.state,
                progress: _actionController.progress,
                errorMessage: _actionController.errorMessage,
                onDismiss: _actionController.dismiss,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review Card ───────────────────────────────────────────────────────────

/// B8: sub-header that groups the review queue by lifecycle type.
class _QueueSectionHeader extends StatelessWidget {
  const _QueueSectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            title.startsWith('Found')
                ? Icons.inventory_2_rounded
                : Icons.fmd_bad_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    required this.onApproveClaim,
  });

  final LostFoundItem item;
  final String adminUid;
  final void Function(ModerationStatus status, {String? reason}) onModerate;
  final ValueChanged<ItemStatus> onStatusChange;
  final void Function(ItemClaim claim) onApproveClaim;

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

              // A4: competing claims — approve one, the rest are rejected
              // server-side and the item resolves.
              const SizedBox(height: 20),
              _ClaimsSection(
                itemId: item.id,
                onApproveClaim: onApproveClaim,
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
                  if (item.status == ItemStatus.pendingClaim)
                    _StatusButton(label: 'Confirm Claim', color: AppColors.success, onTap: () => onStatusChange(ItemStatus.claimed)),
                  if (item.status == ItemStatus.claimed)
                    _StatusButton(label: 'Resolved', color: AppColors.accent, onTap: () => onStatusChange(ItemStatus.resolved)),
                  if (item.status == ItemStatus.resolved)
                    _StatusButton(label: 'Archived', color: AppColors.textTertiary, onTap: () => onStatusChange(ItemStatus.closed)),
                  // Mark as Resolved — available from any non-terminal status
                  if (!item.status.isTerminal && item.status != ItemStatus.resolved)
                    _StatusButton(
                      label: 'Mark as Resolved',
                      color: AppColors.accent,
                      onTap: () => onStatusChange(ItemStatus.resolved),
                    ),
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
                      onTap: () {
                        // Close the detail sheet first, then show reject dialog
                        Navigator.of(context).pop();
                        // We need to call the parent's reject dialog — use a post-frame callback
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          // The parent screen handles the dialog
                        });
                      },
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

// ── Claims section (A4 — non-exclusive claims) ────────────────────────────

/// Live list of every claim submitted on the item, each with an Approve
/// action. Approving one claim rejects the others server-side and resolves
/// the item.
class _ClaimsSection extends StatelessWidget {
  const _ClaimsSection({
    required this.itemId,
    required this.onApproveClaim,
  });

  final String itemId;
  final void Function(ItemClaim claim) onApproveClaim;

  @override
  Widget build(BuildContext context) {
    final Stream<List<ItemClaim>> stream;
    try {
      stream = ItemRepository().streamItemClaims(itemId);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<ItemClaim>>(
      stream: stream,
      builder: (context, snapshot) {
        final claims = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              claims == null ? 'Claims' : 'Claims (${claims.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (claims == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else if (claims.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No claims submitted yet.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              for (final claim in claims)
                _ClaimRow(
                  claim: claim,
                  onApprove: () => onApproveClaim(claim),
                ),
          ],
        );
      },
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.claim, required this.onApprove});

  final ItemClaim claim;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final status = claim.status;
    final color = switch (status) {
      ClaimStatus.submitted => AppColors.primary,
      ClaimStatus.approved => AppColors.success,
      ClaimStatus.rejected => AppColors.error,
    };
    final name = (claim.claimerName != null &&
            claim.claimerName!.trim().isNotEmpty)
        ? claim.claimerName!
        : 'A user';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (claim.createdAt != null)
                Text(
                  _shortClaimDate(claim.createdAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          if (claim.location != null && claim.location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    claim.location!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (claim.note != null && claim.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              claim.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (status == ClaimStatus.submitted)
            _StatusButton(
              label: 'Approve Claim',
              color: AppColors.success,
              onTap: onApprove,
            )
          else
            Row(
              children: [
                Icon(
                  status == ClaimStatus.approved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _shortClaimDate(DateTime date) {
  final local = date.toLocal();
  return '${_monthAbbr[local.month - 1]} ${local.day}, ${local.year}';
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
