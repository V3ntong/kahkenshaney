import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/firestore/item_repository.dart';
import '../data/firestore/notification_service.dart';
import '../models/lost_found_item.dart';
import '../models/resolved_feed_entry.dart';
import '../screens/item_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/user_reports_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_invite_banner.dart';
import '../widgets/confirm_sign_out_dialog.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/feature_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/item_grid_card.dart';
import '../widgets/search_bar.dart';
import 'browse_items_page.dart';

/// Home tab dashboard with real Firestore data.
class HomeFeed extends StatefulWidget {
  const HomeFeed({
    super.key,
    this.userName,
    this.photoUrl,
    this.ownerUid,
    this.overlayDismissed = false,
    this.onTabSelected,
    this.onComingSoon,
    this.onNotifications,
    this.onProfile,
    this.onChangePassword,
    this.onSignOut,
  });

  final String? userName;
  final String? photoUrl;
  final String? ownerUid;
  final bool overlayDismissed;
  final ValueChanged<int>? onTabSelected;
  final ValueChanged<String>? onComingSoon;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onChangePassword;
  final VoidCallback? onSignOut;

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  StreamSubscription<int>? _notifSub;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _listenNotifications();
  }

  void _listenNotifications() {
    final uid = widget.ownerUid;
    if (uid == null || uid.isEmpty) return;
    try {
      _notifSub = NotificationService()
          .streamUnreadCount(uid)
          .listen((count) {
        if (mounted) setState(() => _notificationCount = count);
      }, onError: (_) {});
    } catch (e) {
      // Firebase not ready (e.g. during startup or in tests) — the feed
      // still renders, just without the live badge count.
      debugPrint('[HomeFeed] notifications unavailable: $e');
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _comingSoon(String feature) {
    widget.onComingSoon?.call(feature);
  }

  void _goToTab(int index) => widget.onTabSelected?.call(index);

  void _openChooseAction() {
    Navigator.pushNamed(context, '/choose-action');
  }

  void _openAccountMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                title: const Text('Profile'),
                subtitle: const Text('View account details'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onProfile != null) {
                    widget.onProfile!();
                  } else {
                    _comingSoon('Profile');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: AppColors.info),
                title: const Text('Change Password'),
                subtitle: const Text('Update your account password'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onChangePassword?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                title: const Text('My Reports'),
                subtitle: const Text('Track your submitted reports'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.ownerUid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserReportsScreen(ownerUid: widget.ownerUid!),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                title: const Text('Settings'),
                subtitle: const Text('App preferences and account'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Log out'),
                subtitle: const Text('Sign out of your account'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmSignOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    // C1: shared polished logout dialog (icon, hierarchy, rounded corners).
    final confirmed = await showConfirmSignOutDialog(context);
    if (confirmed == true) {
      widget.onSignOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _staggeredFeedChildren(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Feed sections wrapped in a once-only fadeInDown cascade.
  ///
  /// The entrance fires when the feed is genuinely first built. Because the
  /// Home tab is kept alive, the per-section [FadeSlideInWidget] states
  /// persist, so switching tabs back or minor rebuilds never replay it — only
  /// a real page entry (fresh route / fresh feed) animates.
  List<Widget> _staggeredFeedChildren() {
    final content = <Widget>[
      GreetingHeader(
        userName: widget.userName,
        photoUrl: widget.photoUrl,
        animateReveal: widget.overlayDismissed,
        onNotifications: widget.onNotifications ??
            () => _comingSoon('Notifications'),
        onAvatarTap: _openAccountMenu,
        notificationCount: _notificationCount,
      ),
      const SizedBox(height: 20),
      const AdminInviteBanner(),
      HomeSearchBar(
        onSubmitted: (query) {
          if (query.trim().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BrowseItemsPage(initialSearchQuery: query.trim()),
              ),
            );
          }
        },
        onFilter: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BrowseItemsPage()),
          );
        },
      ),
      const SizedBox(height: 20),
      _PrimaryActions(
        onReportLost: _openChooseAction,
        onReportFound: _openChooseAction,
      ),
      const SizedBox(height: 24),
      if (widget.ownerUid != null && widget.ownerUid!.isNotEmpty)
        _MyReportsStats(ownerUid: widget.ownerUid!),
      const SizedBox(height: 24),
      const _RecentlyResolvedSection(),
      const SizedBox(height: 24),
      _SectionHeader(
        title: 'Explore',
        onViewAll: () => _comingSoon('More features'),
      ),
      const SizedBox(height: 12),
      _buildFeatureGrid(),
      const SizedBox(height: 24),
      _RecentlyReportedSection(
        onViewAll: () => _goToTab(1),
        onItemTap: (item) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ItemDetailScreen(
              item: item,
              heroTagPrefix: 'recent',
            )),
          );
        },
      ),
    ];
    return [
      for (var i = 0; i < content.length; i++)
        FadeSlideInWidget(
          delay: FadeSlideInWidget.staggerDelay(i, perItemMs: 60),
          duration: const Duration(milliseconds: 420),
          child: content[i],
        ),
    ];
  }

  Widget _buildFeatureGrid() {
    return FeatureGrid(
      items: [
        FeatureItem(
          title: 'Reports',
          description: 'Track your lost & found activity',
          icon: Icons.receipt_long_rounded,
          tint: AppColors.primarySurface,
          iconColor: AppColors.primary,
          onTap: () => _goToTab(2),
        ),
        FeatureItem(
          title: 'Messages',
          description: 'Chat with finders in real time',
          icon: Icons.chat_bubble_rounded,
          tint: AppColors.infoSurface,
          iconColor: AppColors.info,
          onTap: () => _goToTab(4),
        ),
        FeatureItem(
          title: 'Found',
          description: 'Browse items people found',
          icon: Icons.inventory_2_rounded,
          tint: const Color(0xFFF0FDF4),
          iconColor: AppColors.success,
          onTap: () => _goToTab(3),
        ),
        FeatureItem(
          title: 'My Reports',
          description: 'View and manage your reports',
          icon: Icons.person_rounded,
          tint: AppColors.primarySurface,
          iconColor: AppColors.primary,
          onTap: () {
            if (widget.ownerUid != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserReportsScreen(ownerUid: widget.ownerUid!),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

// ─── Primary Actions Row ──────────────────────────────────────────────────

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onReportLost,
    required this.onReportFound,
  });

  final VoidCallback onReportLost;
  final VoidCallback onReportFound;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionPill(
            label: 'Report Lost',
            icon: Icons.fmd_bad_rounded,
            color: AppColors.error,
            surface: AppColors.errorSurface,
            onTap: onReportLost,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionPill(
            label: 'Report Found',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            surface: AppColors.successSurface,
            onTap: onReportFound,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.surface,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Reports Stats ─────────────────────────────────────────────────────

class _MyReportsStats extends StatelessWidget {
  const _MyReportsStats({required this.ownerUid});

  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final Stream<List<LostFoundItem>> stream;
    try {
      stream = ItemRepository().streamUserItems(ownerUid);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<LostFoundItem>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <LostFoundItem>[];
        final approved = items.where((i) => i.moderationStatus == ModerationStatus.approved).toList();
        final total = approved.length;
        // "Pending" = every report that has not reached a terminal lifecycle
        // state (claimed / resolved / archived).
        final pending = approved.where((i) => !i.status.isTerminal).length;
        final lost = approved.where((i) => i.kind == ItemKind.lost).length;
        final found = approved.where((i) => i.kind == ItemKind.found).length;
        final resolved = approved.where((i) => i.status.isTerminal).length;

        if (total == 0) return const SizedBox.shrink();

        void openFilter(ReportsFilter filter) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserReportsScreen(ownerUid: ownerUid, filter: filter),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'My Reports'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Pending',
                    value: '$pending',
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.primary,
                    onTap: () => openFilter(ReportsFilter.pending),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Lost',
                    value: '$lost',
                    icon: Icons.fmd_bad_rounded,
                    color: AppColors.error,
                    onTap: () => openFilter(ReportsFilter.lost),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Found',
                    value: '$found',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.success,
                    onTap: () => openFilter(ReportsFilter.found),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Resolved',
                    value: '$resolved',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.info,
                    onTap: () => openFilter(ReportsFilter.resolved),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: tile,
    );
  }
}

// ─── Recently Reported ────────────────────────────────────────────────────

class _RecentlyReportedSection extends StatelessWidget {
  const _RecentlyReportedSection({
    required this.onViewAll,
    required this.onItemTap,
  });

  final VoidCallback onViewAll;
  final ValueChanged<LostFoundItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final Stream<List<LostFoundItem>> lostStream;
    final Stream<List<LostFoundItem>> foundStream;
    try {
      lostStream = ItemRepository().streamItems(kind: ItemKind.lost, limit: 5);
      foundStream =
          ItemRepository().streamItems(kind: ItemKind.found, limit: 5);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<LostFoundItem>>(
      stream: lostStream,
      builder: (context, lostSnap) {
        return StreamBuilder<List<LostFoundItem>>(
          stream: foundStream,
          builder: (context, foundSnap) {
            final lostItems = lostSnap.data ?? const <LostFoundItem>[];
            final foundItems = foundSnap.data ?? const <LostFoundItem>[];
            final all = [...lostItems, ...foundItems]
              ..sort((a, b) => (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0)));

            if (all.isEmpty) return const SizedBox.shrink();

            final groups = _groupByDateBucket(all)
                .entries
                .where((entry) => entry.value.isNotEmpty)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Recently Reported',
                  onViewAll: onViewAll,
                ),
                const SizedBox(height: 12),
                for (var g = 0; g < groups.length; g++) ...[
                  _DateGroupHeader(label: groups[g].key),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: groups[g].value.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = groups[g].value[index];
                        return FadeSlideInWidget(
                          delay: FadeSlideInWidget.staggerDelay(
                            index,
                            perItemMs: 50,
                            maxSpreadMs: 400,
                          ),
                          duration: const Duration(milliseconds: 350),
                          offset: 20,
                          child: SizedBox(
                            width: 150,
                            child: ItemGridCard(
                              item: item,
                              heroTagPrefix: 'recent',
                              onTap: () => onItemTap(item),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (g != groups.length - 1) const SizedBox(height: 16),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Date-bucket labels in display order. Items are grouped by `createdAt`
/// relative to now, in the user's local timezone.
const List<String> _dateBucketLabels = [
  'Today',
  'Yesterday',
  'This Week',
  'This Month',
  'Earlier',
];

/// Buckets [items] (already sorted newest-first) into the labels above while
/// preserving the order inside each bucket.
Map<String, List<LostFoundItem>> _groupByDateBucket(
  List<LostFoundItem> items,
) {
  final now = DateTime.now();
  final groups = {
    for (final label in _dateBucketLabels) label: <LostFoundItem>[],
  };
  for (final item in items) {
    groups[_dateBucketLabel(item.createdAt, now)]!.add(item);
  }
  return groups;
}

String _dateBucketLabel(DateTime? createdAt, DateTime now) {
  if (createdAt == null) return 'Earlier';

  final local = createdAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);

  if (day == today) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return 'Yesterday';
  }
  if (day.isAfter(today.subtract(const Duration(days: 7)))) return 'This Week';
  if (day.year == now.year && day.month == now.month) return 'This Month';
  return 'Earlier';
}

// ─── Date Group Header ────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('View all'),
          ),
      ],
    );
  }
}

// ─── Recently Resolved (public feed, A1) ──────────────────────────────────

/// Public success-story feed published server-side when a claim is approved.
/// Separate from "My Reports" and "Explore"; display names only, no PII.
class _RecentlyResolvedSection extends StatelessWidget {
  const _RecentlyResolvedSection();

  @override
  Widget build(BuildContext context) {
    final Stream<List<ResolvedFeedEntry>> stream;
    try {
      stream = ItemRepository().streamResolvedFeed();
    } catch (_) {
      // Firebase not initialized (startup/tests) — skip the section.
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<ResolvedFeedEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <ResolvedFeedEntry>[];
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Recently Resolved'),
            const SizedBox(height: 12),
            for (var i = 0; i < entries.length; i++) ...[
              _ResolvedFeedCard(entry: entries[i]),
              if (i != entries.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ResolvedFeedCard extends StatelessWidget {
  const _ResolvedFeedCard({required this.entry});

  final ResolvedFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final imageUrl = entry.imageUrl;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _ResolvedFeedThumb(),
                      )
                    : const _ResolvedFeedThumb(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (entry.category != null &&
                            entry.category!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              entry.category!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          _FeedMetaRow(
            icon: Icons.search_rounded,
            iconColor: AppColors.success,
            text: 'Found by ${entry.finderName ?? 'Someone'}',
            trailing: _formatFeedDate(entry.foundAt),
          ),
          if (entry.foundLocation != null &&
              entry.foundLocation!.isNotEmpty)
            _FeedMetaRow(
              icon: Icons.place_rounded,
              iconColor: AppColors.textTertiary,
              text: entry.foundLocation!,
            ),
          if (entry.claimerName != null) ...[
            const SizedBox(height: 6),
            _FeedMetaRow(
              icon: Icons.verified_rounded,
              iconColor: AppColors.primary,
              text: 'Claimed by ${entry.claimerName}',
              trailing: _formatFeedDate(entry.claimAt),
            ),
            if (entry.claimLocation != null &&
                entry.claimLocation!.isNotEmpty)
              _FeedMetaRow(
                icon: Icons.storefront_rounded,
                iconColor: AppColors.textTertiary,
                text: entry.claimLocation!,
              ),
          ],
        ],
      ),
    );
  }
}

class _ResolvedFeedThumb extends StatelessWidget {
  const _ResolvedFeedThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.inventory_2_rounded,
        size: 30,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _FeedMetaRow extends StatelessWidget {
  const _FeedMetaRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatFeedDate(DateTime? date) {
  if (date == null) return '';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
