import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../services/auth_service.dart' show isAdminEmail;
import '../theme/app_theme.dart';
import '../widgets/item_grid_card.dart';
import 'user_chat_screen.dart';

/// Full detail view for a single lost or found item.
///
/// Shows the hero image, item metadata (type, status, category, location,
/// description, timestamps), category row, AI match section (conditional),
/// related items, and action button (Contact Reporter or Mark as Resolved).
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.item});

  final LostFoundItem item;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isResolving = false;

  LostFoundItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final accentSurface =
        isLost ? AppColors.errorSurface : AppColors.successSurface;
    final imageUrl = item.displayUrl;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && currentUid == item.ownerUid;
    final isAdmin = isAdminEmail(FirebaseAuth.instance.currentUser?.email);
    final canContact = currentUid != null &&
        !isOwner &&
        !item.status.isTerminal &&
        item.ownerUid.isNotEmpty &&
        item.ownerUid != 'anonymous';
    final canResolve = isAdmin && !item.status.isTerminal;

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
                decoration: const BoxDecoration(
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
                      child: ClipRect(
                        child: SizedBox.expand(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _Placeholder(
                              accent: accent,
                              surface: accentSurface,
                              isLost: isLost,
                            ),
                          ),
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
                  // Type badge + Status + Category badge
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                      _StatusPill(status: item.status),
                      if (item.category != null &&
                          item.category!.isNotEmpty)
                        _CategoryBadge(category: item.category!),
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
                  const SizedBox(height: 10),

                  // Info rows
                  if (item.location != null && item.location!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: item.location!,
                    ),
                  if (!isLost &&
                      item.storageLocation != null &&
                      item.storageLocation!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.storefront_outlined,
                      label: 'Stored at: ${item.storageLocation}',
                    ),
                  if (item.createdAt != null)
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: _formatDate(item.createdAt!),
                    ),

                  // Category row
                  if (item.category != null && item.category!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.category_outlined,
                      label: item.category!,
                    ),

                  const SizedBox(height: 20),

                  // Description
                  if (item.description.isNotEmpty) ...[
                    const Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.1,
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

                  // Additional photos
                  if (item.media.length > 1) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'ADDITIONAL PHOTOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.media.length - 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
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
                                    size: 28,
                                    color: accent.withValues(alpha: 0.5)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // AI Match section (conditional)
                  _AiMatchSection(
                    item: item,
                    onItemTap: (matchedItem) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: matchedItem),
                        ),
                      );
                    },
                  ),

                  // Contact Reporter button (non-owners)
                  if (canContact) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _contactReporter(context),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: const Text('Contact Reporter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Mark as Resolved button (owners)
                  if (canResolve) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _isResolving ? null : () => _markAsResolved(),
                        icon: _isResolving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded,
                                size: 18),
                        label: Text(
                            _isResolving ? 'Resolving...' : 'Mark as Resolved'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Related Items
                  const SizedBox(height: 28),
                  _RelatedItemsSection(
                    currentItemId: item.id,
                    category: item.category,
                    currentItem: item,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _contactReporter(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserChatScreen(
          userId: currentUid,
          adminUid: '',
          peerUid: item.ownerUid,
          peerName: item.title,
        ),
      ),
    );
  }

  Future<void> _markAsResolved() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);

    try {
      await ItemRepository().updateItemFields(item.id, {
        'status': 'claimed',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as resolved')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resolve item')),
        );
      }
    }
  }
}

// ─── Category Badge ───────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── AI Match Section ─────────────────────────────────────────────────────

class _AiMatchSection extends StatelessWidget {
  const _AiMatchSection({
    required this.item,
    required this.onItemTap,
  });

  final LostFoundItem item;
  final ValueChanged<LostFoundItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    // Only show for items with a category
    if (item.category == null || item.category!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<LostFoundItem>>(
      stream: ItemRepository().streamPotentialMatches(
        currentItemId: item.id,
        currentKind: item.kind,
        category: item.category,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final matches = snapshot.data ?? const <LostFoundItem>[];
        if (matches.isEmpty) return const SizedBox.shrink();

        // Show the best match (first item, newest)
        final bestMatch = matches.first;
        final matchCount = matches.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'POSSIBLE MATCH',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => onItemTap(bestMatch),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: bestMatch.displayUrl != null
                          ? Image.network(
                              bestMatch.displayUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 56,
                                height: 56,
                                color: AppColors.surface,
                                child: Icon(
                                  bestMatch.kind == ItemKind.lost
                                      ? Icons.fmd_bad_rounded
                                      : Icons.inventory_2_rounded,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: AppColors.surface,
                              child: Icon(
                                bestMatch.kind == ItemKind.lost
                                    ? Icons.fmd_bad_rounded
                                    : Icons.inventory_2_rounded,
                                size: 24,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bestMatch.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bestMatch.kind == ItemKind.lost
                                ? 'Reported lost'
                                : 'Found item',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (matchCount > 1) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+${matchCount - 1} more match${matchCount > 2 ? 'es' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // View button
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Related Items ────────────────────────────────────────────────────────

class _RelatedItemsSection extends StatelessWidget {
  const _RelatedItemsSection({
    required this.currentItemId,
    this.category,
    required this.currentItem,
  });

  final String currentItemId;
  final String? category;
  final LostFoundItem currentItem;

  @override
  Widget build(BuildContext context) {
    if (category == null || category!.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<LostFoundItem>>(
      stream: ItemRepository().streamItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final allItems = snapshot.data ?? const <LostFoundItem>[];

        // Score-based related items matching
        final scored = allItems
            .where((i) => i.id != currentItemId && !i.status.isTerminal)
            .map((i) => (item: i, score: _relatedScore(i, category!, currentItem)))
            .where((e) => e.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

        final related = scored.take(4).map((e) => e.item).toList();

        if (related.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RELATED ITEMS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: related.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 140,
                    child: ItemGridCard(
                      item: related[index],
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ItemDetailScreen(item: related[index]),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Placeholder ──────────────────────────────────────────────────────────

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

// ─── Info Row ─────────────────────────────────────────────────────────────

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

// ─── Status Pill ──────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      ItemStatus.open => ('OPEN', AppColors.success, AppColors.successSurface),
      ItemStatus.pendingVerification =>
        ('PENDING', AppColors.warning, AppColors.warningSurface),
      ItemStatus.verified =>
        ('VERIFIED', AppColors.info, AppColors.infoSurface),
      ItemStatus.matched =>
        ('MATCHED', AppColors.primary, AppColors.infoSurface),
      ItemStatus.claimed =>
        ('CLAIMED', AppColors.success, AppColors.successSurface),
      ItemStatus.resolved =>
        ('RESOLVED', AppColors.accent, AppColors.successSurface),
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

// ─── Related Items Scoring ─────────────────────────────────────────────────

/// Scores how related another item is to the current one.
/// Higher score = more relevant. Returns 0 if not related at all.
int _relatedScore(LostFoundItem other, String currentCategory, LostFoundItem current) {
  int score = 0;

  // Same category = strong match
  if (other.category == currentCategory) score += 10;

  // Similar title keywords = moderate match
  final currentWords = current.title.toLowerCase().split(RegExp(r'\s+'));
  final otherWords = other.title.toLowerCase().split(RegExp(r'\s+'));
  final sharedWords = currentWords.where((w) => w.length > 2 && otherWords.contains(w)).length;
  score += sharedWords * 3;

  // Same location = slight match
  if (other.location != null &&
      current.location != null &&
      other.location!.toLowerCase() == current.location!.toLowerCase()) {
    score += 2;
  }

  return score;
}

// ─── Date Formatting ──────────────────────────────────────────────────────

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = date.hour;
  final m = date.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour12:$m $period';
}
