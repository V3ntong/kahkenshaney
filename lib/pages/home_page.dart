import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../screens/item_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../widgets/tab_switcher.dart';
import 'home_feed.dart';
import 'items_grid_page.dart';
import 'messages_page.dart';
import 'reports_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.userName,
    this.userEmail,
    this.photoUrl,
    this.ownerUid,
    this.onChangePassword,
    this.onSignOut,
    this.onTabChanged,
    this.unreadCount = 0,
    this.overlayDismissed = false,
  });

  final String? userName;
  final String? userEmail;
  final String? photoUrl;
  final String? ownerUid;
  final VoidCallback? onChangePassword;
  final VoidCallback? onSignOut;
  final ValueChanged<int>? onTabChanged;
  final int unreadCount;
  final bool overlayDismissed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    KeepAliveWrapper(
      child: HomeFeed(
        userName: widget.userName,
        photoUrl: widget.photoUrl,
        ownerUid: widget.ownerUid,
        overlayDismissed: widget.overlayDismissed,
        onAiScan: () => _comingSoon('AI Scan'),
        onTabSelected: _goToTab,
        onComingSoon: _comingSoon,
        onNotifications: _showNotifications,
        onProfile: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        onChangePassword: widget.onChangePassword,
        onSignOut: widget.onSignOut,
      ),
    ),
    KeepAliveWrapper(
      child: ItemsGridPage(
        kind: ItemKind.lost,
        bannerTitle: 'Lost Items',
        bannerSubtitle: 'Browse items others have reported missing',
        ctaLabel: 'Report Lost Item',
        onCtaTap: () => Navigator.pushNamed(context, '/report-lost'),
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'Nothing lost yet',
        emptyMessage:
            'When you report a lost item it will show up here so we can match it.',
      ),
    ),
    const KeepAliveWrapper(child: ReportsPage()),
    KeepAliveWrapper(
      child: ItemsGridPage(
        kind: ItemKind.found,
        bannerTitle: 'Found Items',
        bannerSubtitle: 'Help reunite found items with their owners',
        ctaLabel: 'Found an Item?',
        onCtaTap: () => Navigator.pushNamed(context, '/submit-found'),
        emptyIcon: Icons.inventory_2_rounded,
        emptyTitle: 'Nothing found yet',
        emptyMessage:
            'Found something? Submit it and help reunite it with its owner.',
      ),
    ),
    KeepAliveWrapper(
      child: MessagesPage(userId: widget.ownerUid),
    ),
  ];

  void _goToTab(int index) {
    if (index == _selectedIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  void _showNotifications() {
    if (widget.ownerUid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          userId: widget.ownerUid!,
          onNotificationTap: (itemId) {
            if (itemId != null && itemId.isNotEmpty) {
              _navigateToItem(itemId);
            }
          },
        ),
      ),
    );
  }

  Future<void> _navigateToItem(String itemId) async {
    try {
      final item = await ItemRepository().getItem(itemId);
      if (item != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: item),
          ),
        );
      }
    } catch (e) {
      debugPrint('[HomePage] Error navigating to item: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: TabSwitcher(
        controller: _pageController,
        pages: _pages,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
          widget.onTabChanged?.call(index);
        },
      ),
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _goToTab,
        unreadCount: widget.unreadCount,
      ),
    );
  }
}
