import 'package:flutter/material.dart';

import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../widgets/tab_switcher.dart';
import 'home_feed.dart';
import 'item_list_page.dart';
import 'messages_page.dart';
import 'reports_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.userName,
    this.userEmail,
    this.onChangePassword,
    this.onSignOut,
  });

  final String? userName;
  final String? userEmail;
  final VoidCallback? onChangePassword;
  final VoidCallback? onSignOut;

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
        onAiScan: () => _comingSoon('AI Scan'),
        onTabSelected: _goToTab,
        onComingSoon: _comingSoon,
        onNotifications: _showNotifications,
        onProfile: () => _comingSoon('Profile'),
      ),
    ),
    KeepAliveWrapper(
      child: ItemsListPage(
        kind: ItemKind.lost,
        title: 'Lost',
        subtitle: 'Items reported as lost',
        accent: AppColors.error,
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'Nothing lost yet',
        emptyMessage:
            'When you report a lost item it will show up here so we can match it.',
      ),
    ),
    const KeepAliveWrapper(child: ReportsPage()),
    KeepAliveWrapper(
      child: ItemsListPage(
        kind: ItemKind.found,
        title: 'Found',
        subtitle: 'Items reported as found',
        accent: AppColors.success,
        emptyIcon: Icons.inventory_2_rounded,
        emptyTitle: 'Nothing found yet',
        emptyMessage:
            'Found something? Submit it and help reunite it with its owner.',
      ),
    ),
    const KeepAliveWrapper(child: MessagesPage()),
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
    _comingSoon('Notifications');
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
        onPageChanged: (index) => setState(() => _selectedIndex = index),
      ),
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _goToTab,
      ),
    );
  }
}
