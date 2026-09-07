import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../services/auth_service.dart' show isAdminEmail;
import '../data/firestore/notification_service.dart';
import '../services/claim_api.dart';
import '../services/match_api.dart';
import '../services/resolve_api.dart';
import '../theme/app_theme.dart';
import '../widgets/centered_success_overlay.dart';
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
  bool _isClaiming = false;
  bool _isConfirmingMatch = false;
  StreamSubscription<LostFoundItem?>? _itemSub;
  LostFoundItem? _liveItem;

  /// The item as currently known. Subscribes to the Firestore document so
  /// status changes, claims and match scores update live.
  LostFoundItem get item => _liveItem ?? widget.item;

  @override
  void initState() {
    super.initState();
    _itemSub = ItemRepository().streamItem(widget.item.id).listen((live) {
      if (!mounted || live == null) return;
      setState(() => _liveItem = live);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _itemSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final accentSurface = isLost
        ? AppColors.errorSurface
        : AppColors.successSurface;
    final imageUrl = item.displayUrl;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && currentUid == item.ownerUid;
    final isAdmin = isAdminEmail(FirebaseAuth.instance.currentUser?.email);
    final canContact =
        currentUid != null &&
        !isOwner &&
        !item.status.isTerminal &&
        item.ownerUid.isNotEmpty &&
        item.ownerUid != 'anonymous';
    // Resolution is an administrative lifecycle transition. The callable
    // enforces this again server-side; this guard keeps the control out of
    // every regular user's UI.
    // Show when: (1) the viewer is an admin (synchronous email check), AND
    // (2) the item status is NOT terminal (claimed/resolved/closed).
    // NOTE: isAdminEmail() checks only the hardcoded kAdminEmail. If a
    // dynamically-added admin (adminEmails collection) cannot see this
    // button, switch to isAdminAuthenticated from AuthService instead.
    final canResolve = !item.status.isTerminal && isAdmin;
    // Claimability rule: a non-admin, non-owner, non-reporter user may claim
    // an item whose status is non-terminal and which has no pending/accepted
    // claim yet.  The server-side `claimItem` Cloud Function mirrors this.
    final canClaim = item.canBeClaimedBy(currentUid ?? '', isAdmin: isAdmin);

    debugPrint(
      '[ItemDetail] uid=$currentUid  owner=${item.ownerUid}  '
      'status=${item.status.name}  modStatus=${item.moderationStatus.name}  '
      'reportedBy=${item.reportedBy}  claimedBy=${item.claimedBy}  '
      'isAdmin=$isAdmin  isOwner=$isOwner  '
      'canClaim=$canClaim  canResolve=$canResolve  canContact=$canContact',
    );

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
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
                          horizontal: 10,
                          vertical: 5,
                        ),
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
                      if (item.category != null && item.category!.isNotEmpty)
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
                    _InfoRow(icon: Icons.place_outlined, label: item.location!),
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
                    Row(
                      children: [
                        const Text(
                          'ADDITIONAL PHOTOS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${item.media.length - 1})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.media.length - 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final photoUrl = item.media[index + 1];
                          return GestureDetector(
                            onTap: () => _openPhotoViewer(
                              context,
                              item.media,
                              index + 1,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                photoUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 100,
                                  height: 100,
                                  color: accentSurface,
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 28,
                                    color: accent.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Suggested Matches (stored scores or category fallback)
                  _SuggestedMatchesSection(
                    item: item,
                    canConfirmMatch:
                        !item.status.isTerminal &&
                        (isAdmin ||
                            (currentUid != null &&
                                (currentUid == item.ownerUid ||
                                    (item.reportedBy.isNotEmpty &&
                                        currentUid == item.reportedBy)))),
                    onConfirmMatch: _confirmMatch,
                    onItemTap: (matchedItem) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: matchedItem),
                        ),
                      );
                    },
                  ),

                  // Claim This Item button (non-owners)
                  if (canClaim) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isClaiming ? null : () => _claimItem(),
                        icon: _isClaiming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.how_to_reg_rounded, size: 18),
                        label: Text(
                          _isClaiming
                              ? 'Submitting claim...'
                              : 'Claim This Item',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
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

                  // Contact Reporter button (non-owners)
                  if (canContact) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _contactReporter(context),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
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
                        onPressed: _isResolving
                            ? null
                            : () => _markAsResolved(),
                        icon: _isResolving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isResolving ? 'Resolving...' : 'Mark as Resolved',
                        ),
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

  /// Opens a full-screen photo viewer for the given media list.
  void _openPhotoViewer(
    BuildContext context,
    List<String> media,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhotoViewer(
          media: media,
          initialIndex: initialIndex,
        ),
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

  Future<void> _claimItem() async {
    if (_isClaiming) return;

    if (item.ownerUid == FirebaseAuth.instance.currentUser?.uid) {
      if (!mounted) return;
      setState(() => _isClaiming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot claim your own item')),
      );
      return;
    }

    setState(() => _isClaiming = true);

    try {
      await ClaimApi().claimItem(item.id);
      if (!mounted) return;
      setState(() => _isClaiming = false);
      CenteredSuccessOverlay.show(
        context,
        message: 'Claim submitted for review',
      );

      // Fire-and-forget: notify the item reporter + admin.
      // Wrapped in their own try-catch so a notification failure
      // never masks the already-successful claim.
      try {
        final notifService = NotificationService();
        await notifService.createNotification(
          userId: item.ownerUid,
          title: 'Claim Submitted',
          body: 'A claim has been submitted for your ${item.kind.name} item "${item.title}".',
          type: 'status_pendingClaim',
          relatedItemId: item.id,
        );
        await notifService.notifyAdminNewReport(item: item);
      } catch (_) {
        debugPrint('[ItemDetail] Non-critical: post-claim notifications failed');
      }
    } on ClaimApiException catch (e) {
      if (!mounted) return;
      setState(() => _isClaiming = false);
      // Surface the server's message (e.g. self-claim rejection).
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isClaiming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to submit claim')));
    }
  }

  /// Confirms [match] as the linked counterpart of this item via the
  /// server-side `confirmMatch` callable (updates `matchedItemId` + status
  /// on BOTH documents).
  Future<void> _confirmMatch(ItemMatchScore match) async {
    if (_isConfirmingMatch) return;
    setState(() => _isConfirmingMatch = true);
    try {
      await MatchApi().confirmMatch(
        itemId: item.id,
        matchedItemId: match.itemId,
      );
      if (!mounted) return;
      setState(() => _isConfirmingMatch = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Match confirmed')));
    } on MatchApiException catch (e) {
      if (!mounted) return;
      setState(() => _isConfirmingMatch = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirmingMatch = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to confirm match')));
    }
  }

  Future<void> _markAsResolved() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);

    try {
      // Server-side lifecycle: validates the caller, writes the terminal
      // status + resolvedAt/resolvedBy + history, and notifies the other
      // party. The live item stream refreshes the UI afterwards.
      await ResolveApi().resolveItem(item.id);
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as resolved')),
        );
      }
    } on ResolveApiException catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to resolve item')));
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

// ─── Suggested Matches Section ────────────────────────────────────────────

/// Shows smart-match candidates ranked by score.
///
/// Prefers the server-computed [LostFoundItem.matchScores] (stored on the
/// item document by the matching Cloud Function) so scores are never
/// recomputed on page load. Falls back to the category-based live query for
/// items created before the matcher existed.
class _SuggestedMatchesSection extends StatelessWidget {
  const _SuggestedMatchesSection({
    required this.item,
    required this.onItemTap,
    this.canConfirmMatch = false,
    this.onConfirmMatch,
  });

  final LostFoundItem item;
  final ValueChanged<LostFoundItem> onItemTap;

  /// Whether the viewer (reporter/admin) may link a suggested match.
  final bool canConfirmMatch;
  final ValueChanged<ItemMatchScore>? onConfirmMatch;

  @override
  Widget build(BuildContext context) {
    final stored = item.matchScores;
    if (stored.isNotEmpty) {
      final ranked = [...stored]..sort((a, b) => b.score.compareTo(a.score));
      return _buildRankedList(context, ranked.take(5).toList());
    }
    return _buildFallback(context);
  }

  /// Ranked list from persisted match scores.
  Widget _buildRankedList(BuildContext context, List<ItemMatchScore> matches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'SUGGESTED MATCHES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        ...matches.map(
          (match) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MatchCard(
              score: match.score,
              title: match.title,
              kind: match.kind,
              onTap: () => _openMatch(context, match.itemId),
              onConfirm: canConfirmMatch && onConfirmMatch != null
                  ? () => onConfirmMatch!(match)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the matched item's detail page (fetched by ID).
  Future<void> _openMatch(BuildContext context, String itemId) async {
    try {
      final matched = await ItemRepository().getItem(itemId);
      if (matched != null && context.mounted) {
        onItemTap(matched);
      }
    } catch (e) {
      debugPrint('[ItemDetail] Error opening suggested match: $e');
    }
  }

  /// Category-based live fallback (pre-matcher behavior).
  Widget _buildFallback(BuildContext context) {
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
            _MatchCard(
              score: null,
              title: bestMatch.title,
              kind: bestMatch.kind,
              subtitle: matchCount > 1
                  ? '+${matchCount - 1} more match${matchCount > 2 ? 'es' : ''}'
                  : null,
              onTap: () => onItemTap(bestMatch),
            ),
          ],
        );
      },
    );
  }
}

/// A single suggested-match row with a confidence score.
class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.title,
    required this.kind,
    required this.onTap,
    this.score,
    this.subtitle,
    this.onConfirm,
  });

  final int? score;
  final String title;
  final ItemKind kind;
  final String? subtitle;
  final VoidCallback onTap;

  /// When set, shows a compact "confirm/link" action on the card.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                kind == ItemKind.lost
                    ? Icons.fmd_bad_rounded
                    : Icons.inventory_2_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    subtitle ??
                        (kind == ItemKind.lost
                            ? 'Reported lost'
                            : 'Found item'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (score != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: score! >= 70
                      ? AppColors.successSurface
                      : AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score% match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: score! >= 70 ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
            if (onConfirm != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onConfirm,
                tooltip: 'Confirm this match',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
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
        final scored =
            allItems
                .where((i) => i.id != currentItemId && !i.status.isTerminal)
                .map(
                  (i) => (
                    item: i,
                    score: _relatedScore(i, category!, currentItem),
                  ),
                )
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
              height: 260,
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
      ItemStatus.pendingVerification => (
        'PENDING',
        AppColors.warning,
        AppColors.warningSurface,
      ),
      ItemStatus.verified => (
        'VERIFIED',
        AppColors.info,
        AppColors.infoSurface,
      ),
      ItemStatus.matched => (
        'MATCHED',
        AppColors.primary,
        AppColors.infoSurface,
      ),
      ItemStatus.pendingClaim => (
        'CLAIM PENDING',
        AppColors.warning,
        AppColors.warningSurface,
      ),
      ItemStatus.claimed => (
        'CLAIMED',
        AppColors.success,
        AppColors.successSurface,
      ),
      ItemStatus.resolved => (
        'RESOLVED',
        AppColors.accent,
        AppColors.successSurface,
      ),
      ItemStatus.closed => (
        'CLOSED',
        AppColors.textTertiary,
        AppColors.surfaceVariant,
      ),
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
int _relatedScore(
  LostFoundItem other,
  String currentCategory,
  LostFoundItem current,
) {
  int score = 0;

  // Same category = strong match
  if (other.category == currentCategory) score += 10;

  // Similar title keywords = moderate match
  final currentWords = current.title.toLowerCase().split(RegExp(r'\s+'));
  final otherWords = other.title.toLowerCase().split(RegExp(r'\s+'));
  final sharedWords = currentWords
      .where((w) => w.length > 2 && otherWords.contains(w))
      .length;
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = date.hour;
  final m = date.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour12:$m $period';
}

// ─── Full-Screen Photo Viewer ─────────────────────────────────────────────

class _FullScreenPhotoViewer extends StatefulWidget {
  const _FullScreenPhotoViewer({
    required this.media,
    required this.initialIndex,
  });

  final List<String> media;
  final int initialIndex;

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.media.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.media.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.media[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 48,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
