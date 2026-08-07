import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ai_suggestion_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_card.dart';
import '../widgets/report_tile.dart';
import '../widgets/search_bar.dart';
import '../widgets/summary_card.dart';

/// The premium Home tab dashboard: greeting header, search, featured summary
/// card, quick-feature grid, recent reports and AI suggestions.
///
/// Held in a keep-alive wrapper by the navigation shell so its scroll
/// position and search input survive tab switches.
class HomeFeed extends StatefulWidget {
  const HomeFeed({
    super.key,
    this.userName,
    this.onAiScan,
    this.onTabSelected,
    this.onComingSoon,
    this.onNotifications,
    this.onProfile,
  });

  final String? userName;
  final VoidCallback? onAiScan;
  final ValueChanged<int>? onTabSelected;
  final ValueChanged<String>? onComingSoon;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

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
                      onAvatarTap: widget.onProfile ?? () => _goToTab(4),
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
                    _SectionHeader(
                      title: 'Recent Reports',
                      onViewAll: () => _goToTab(2),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentReports(context),
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

  Widget _buildRecentReports(BuildContext context) {
    const reports = [
      ReportItem(
        itemName: 'Black Tumbler',
        location: 'Library • Level 2',
        timeAgo: '2h ago',
        status: ReportStatus.lost,
        icon: Icons.local_drink_rounded,
        tint: Color(0x1AEF4444),
      ),
      ReportItem(
        itemName: 'Umbrella',
        location: 'Main Gate',
        timeAgo: '5h ago',
        status: ReportStatus.found,
        icon: Icons.beach_access_rounded,
        tint: Color(0x1A22C55E),
      ),
      ReportItem(
        itemName: 'Calculator',
        location: 'IT Lab 3',
        timeAgo: '1d ago',
        status: ReportStatus.matched,
        icon: Icons.calculate_rounded,
        tint: Color(0x1A2563EB),
      ),
    ];
    return HomeCard(
      radius: 24,
      child: Column(
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            ReportTile(report: reports[i]),
            if (i != reports.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
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