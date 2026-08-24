import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_suggestion_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/summary_card.dart';

/// The premium Home tab dashboard: greeting header, search, featured summary
/// card, quick-feature grid, status tracking, recent reports and AI
/// suggestions.
///
/// Held in a keep-alive wrapper by the navigation shell so its scroll
/// position and search input survive tab switches.
class HomeFeed extends StatefulWidget {
  const HomeFeed({
    super.key,
    this.userName,
    this.ownerUid,
    this.onAiScan,
    this.onTabSelected,
    this.onComingSoon,
    this.onNotifications,
    this.onProfile,
    this.onChangePassword,
    this.onSignOut,
  });

  final String? userName;
  final String? ownerUid;
  final VoidCallback? onAiScan;
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
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of KAH KEN SHA NEY?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GreetingHeader(
                      userName: widget.userName,
                      onNotifications: widget.onNotifications ??
                          () => _comingSoon('Notifications'),
                      onAvatarTap: _openAccountMenu,
                      notificationCount: 2,
                    ),
                    const SizedBox(height: 20),
                    HomeSearchBar(
                      onSubmitted: (_) => _comingSoon('Item search'),
                      onFilter: () => _comingSoon('Filters'),
                    ),
                    const SizedBox(height: 20),
                    DashboardSummaryCard(
                      label: 'This Month',
                      value: 12,
                      valueUnit: 'items',
                      subtitle:
                          'AI matching reunited you with 3 items this week.',
                      onReportLost: _openChooseAction,
                      onReportFound: _openChooseAction,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Explore',
                      onViewAll: () => _comingSoon('More features'),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureGrid(),
                    const SizedBox(height: 24),
                    _UserReportsSection(
                      ownerUid: widget.ownerUid,
                      onViewAll: () => _goToTab(2),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'AI Suggestions',
                      onViewAll: () => _comingSoon('All suggestions'),
                    ),
                    const SizedBox(height: 12),
                    _buildAiSuggestions(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
          title: 'AI Scan',
          description: 'Match items with smart vision',
          icon: Icons.auto_awesome_rounded,
          tint: const Color(0xFFF0FDF4),
          iconColor: AppColors.accent,
          onTap: widget.onAiScan ?? () => _comingSoon('AI Scan'),
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
      ],
    );
  }

  Widget _buildAiSuggestions(BuildContext context) {
    return Column(
      children: const [
        AISuggestionCard(
          suggestion: AISuggestion(
            text: 'Your "Black Tumbler" matches a found item in the Library.',
            confidence: 92,
          ),
        ),
        SizedBox(height: 12),
        AISuggestionCard(
          suggestion: AISuggestion(
            text: 'A nearby lost item matches the umbrella you reported.',
            confidence: 78,
          ),
        ),
      ],
    );
  }
}

class _UserReportsSection extends StatefulWidget {
  const _UserReportsSection({
    required this.ownerUid,
    required this.onViewAll,
  });

  final String? ownerUid;
  final VoidCallback onViewAll;

  @override
  State<_UserReportsSection> createState() => _UserReportsSectionState();
}

class _UserReportsSectionState extends State<_UserReportsSection> {
  ItemRepository? _repository;
  Stream<List<LostFoundItem>>? _stream;
  LostFoundItem? _selected;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  Stream<List<LostFoundItem>>? _buildStream() {
    final ownerUid = widget.ownerUid;
    if (ownerUid == null || ownerUid.isEmpty) return null;
    _repository ??= ItemRepository();
    return _repository!.streamUserItems(ownerUid);
  }

  void _retry() {
    setState(() => _stream = _buildStream());
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) {
      return _ReportsEmptyState(onViewAll: widget.onViewAll);
    }

    return StreamBuilder<List<LostFoundItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ReportsLoadingState();
        }
        if (snapshot.hasError) {
          return _ReportsErrorState(onRetry: _retry);
        }
        final items = snapshot.data ?? const <LostFoundItem>[];
        if (items.isEmpty) {
          return _ReportsEmptyState(onViewAll: widget.onViewAll);
        }

        final selected = (_selected != null &&
                items.any((item) => item.id == _selected!.id))
            ? _selected!
            : items.first;

        final visible = items.length > 5 ? items.take(5).toList() : items;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Status Tracking'),
            const SizedBox(height: 12),
            _StatusTrackerCard(status: selected.status),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Recent Reports'),
            const SizedBox(height: 12),
            HomeCard(
              padding: EdgeInsets.zero,
              radius: 20,
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    _ReportRow(
                      item: visible[i],
                      selected: visible[i].id == selected.id,
                      onTap: () => setState(() => _selected = visible[i]),
                    ),
                    if (i != visible.length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                  _ViewAllReportsButton(onPressed: widget.onViewAll),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusTrackerCard extends StatelessWidget {
  const _StatusTrackerCard({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final index = status.index;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report Progress',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              Text(
                status.shortLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < ItemStatus.values.length; i++) ...[
                  _StageNode(
                    stage: ItemStatus.values[i],
                    state: i < index
                        ? _StageState.done
                        : (i == index
                            ? _StageState.current
                            : _StageState.upcoming),
                  ),
                  if (i < ItemStatus.values.length - 1)
                    _StageConnector(done: i < index),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StageState { done, current, upcoming }

class _StageNode extends StatelessWidget {
  const _StageNode({required this.stage, required this.state});

  final ItemStatus stage;
  final _StageState state;

  static const Map<ItemStatus, IconData> _icons = {
    ItemStatus.open: Icons.send_rounded,
    ItemStatus.pendingVerification: Icons.hourglass_top_rounded,
    ItemStatus.verified: Icons.verified_rounded,
    ItemStatus.matched: Icons.handshake_rounded,
    ItemStatus.claimed: Icons.check_circle_rounded,
    ItemStatus.closed: Icons.archive_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final upcoming = state == _StageState.upcoming;
    final icon = _icons[stage]!;

    return SizedBox(
      width: 92,
      child: Column(
        children: [
          if (state == _StageState.current)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: AppColors.softShadow,
              ),
              child: Icon(icon, size: 19, color: Colors.white),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: upcoming ? AppColors.surfaceVariant : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                state == _StageState.done ? Icons.check_rounded : icon,
                size: 18,
                color: upcoming ? AppColors.textTertiary : Colors.white,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight:
                  state == _StageState.current ? FontWeight.w700 : FontWeight.w500,
              color: upcoming ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageConnector extends StatelessWidget {
  const _StageConnector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 3,
      margin: const EdgeInsets.only(top: 17),
      decoration: BoxDecoration(
        color: done ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LostFoundItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lost = item.kind == ItemKind.lost;
    final accent = lost ? AppColors.error : AppColors.success;
    final surface = lost ? AppColors.errorSurface : AppColors.successSurface;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? surface.withValues(alpha: 0.45) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                lost ? Icons.fmd_bad_rounded : Icons.inventory_2_rounded,
                size: 18,
                color: accent,
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
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lost ? 'Lost' : 'Found'} • '
                    '${_formatRelativeDate(item.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CompactStatus(status: item.status),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 17,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

(String, Color, Color) _statusColors(ItemStatus status) => switch (status) {
      ItemStatus.open => (
          ItemStatus.open.shortLabel,
          AppColors.info,
          AppColors.infoSurface
        ),
      ItemStatus.pendingVerification => (
          ItemStatus.pendingVerification.shortLabel,
          AppColors.warning,
          AppColors.warningSurface
        ),
      ItemStatus.verified => (
          ItemStatus.verified.shortLabel,
          AppColors.success,
          AppColors.successSurface
        ),
      ItemStatus.matched => (
          ItemStatus.matched.shortLabel,
          AppColors.primary,
          AppColors.primarySurface
        ),
      ItemStatus.claimed => (
          ItemStatus.claimed.shortLabel,
          AppColors.info,
          AppColors.infoSurface
        ),
      ItemStatus.closed => (
          ItemStatus.closed.shortLabel,
          AppColors.textSecondary,
          AppColors.surfaceVariant
        ),
    };

class _ViewAllReportsButton extends StatelessWidget {
  const _ViewAllReportsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('View All Reports'),
      ),
    );
  }
}

class _ReportsLoadingState extends StatelessWidget {
  const _ReportsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const HomeCard(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading your reports…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 38, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          const Text(
            'Couldn\'t load your reports.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              size: 38, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          const Text(
            'No reports yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lost something or found an item? Report it to start tracking '
            'its status here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('View All Reports'),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeDate(DateTime? date) {
  if (date == null) return '—';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

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