import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import 'item_detail_screen.dart';

/// Admin: every item record of a single kind, newest first.
///
/// Opened from the dashboard overview's "Lost Items" / "Found Items" cards
/// (B1) so admins land on the records behind each count. Uses the dashboard's
/// live items stream when provided, otherwise its own repository stream.
class AdminItemsListScreen extends StatefulWidget {
  const AdminItemsListScreen({
    super.key,
    required this.kind,
    this.itemsStream,
    this.repository,
  });

  final ItemKind kind;

  /// The dashboard's `AdminRepository.streamAllItems()` — shared so the
  /// counts on the cards and the rows in this list stay in sync.
  final Stream<List<LostFoundItem>>? itemsStream;

  /// Fallback when no stream is provided (e.g. pushed standalone).
  final ItemRepository? repository;

  @override
  State<AdminItemsListScreen> createState() => _AdminItemsListScreenState();
}

class _AdminItemsListScreenState extends State<AdminItemsListScreen> {
  Stream<List<LostFoundItem>>? _stream;
  bool _streamUnavailable = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.itemsStream;
    if (_stream == null) {
      try {
        _stream =
            (widget.repository ?? ItemRepository()).streamAllItemsForAdmin();
      } catch (_) {
        _streamUnavailable = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLost = widget.kind == ItemKind.lost;
    final title = isLost ? 'Lost Items' : 'Found Items';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: _streamUnavailable || _stream == null
          ? const _ListMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Live data unavailable',
              message: 'Item records could not be loaded right now.',
            )
          : StreamBuilder<List<LostFoundItem>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (snapshot.hasError) {
                  return _ListMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load reports',
                    message: snapshot.error.toString(),
                  );
                }

                final items = (snapshot.data ?? const <LostFoundItem>[])
                    .where((item) => item.kind == widget.kind)
                    .toList();

                if (items.isEmpty) {
                  return _ListMessage(
                    icon: isLost
                        ? Icons.fmd_bad_rounded
                        : Icons.inventory_2_rounded,
                    title: 'No $title yet',
                    message: 'New ${isLost ? 'lost' : 'found'} reports will '
                        'appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _AdminItemRow(item: items[index]),
                );
              },
            ),
    );
  }
}

class _AdminItemRow extends StatelessWidget {
  const _AdminItemRow({required this.item});

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final createdAt = item.createdAt;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              item: item,
              heroTagPrefix: 'admin-list',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: item.displayUrl != null
                    ? Image.network(item.displayUrl!, fit: BoxFit.cover)
                    : Container(
                        color: accent.withValues(alpha: 0.1),
                        child: Icon(
                          isLost
                              ? Icons.fmd_bad_rounded
                              : Icons.inventory_2_rounded,
                          color: accent,
                          size: 22,
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
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (item.location != null &&
                          item.location!.isNotEmpty)
                        item.location!,
                      if (createdAt != null)
                        '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year}',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge.fromItemStatus(item.status),
                const SizedBox(height: 4),
                Text(
                  item.moderationStatus.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: switch (item.moderationStatus) {
                      ModerationStatus.approved => AppColors.success,
                      ModerationStatus.pending => AppColors.warning,
                      ModerationStatus.rejected => AppColors.error,
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
