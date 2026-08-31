import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:cloud_functions/cloud_functions.dart';

import '../data/firestore/admin_repository.dart';
import '../data/firestore/database_service.dart';
import '../mainpage.dart';
import '../models/lost_found_item.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/app_logo.dart';
import '../widgets/image_picker_sheet.dart';
import '../widgets/metric_counter.dart';
import 'admin_inbox_screen.dart';
import 'admin_review_queue_screen.dart';
import 'auth/login.dart';
import 'dashboard.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Admin-only Lost & Found control center.
///
/// Guarded so only the designated admin email can use it. Responsive: a fixed
/// sidebar on wide screens, a drawer-based navigation on narrow screens.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.authService, this.repository});

  final AuthService? authService;

  /// Injectable for tests; defaults to Firestore-backed [AdminRepository].
  final AdminRepository? repository;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  AdminRepository? _repository;
  Stream<List<LostFoundItem>>? _itemsStream;
  Stream<int>? _usersStream;
  Stream<List<Map<String, dynamic>>>? _usersListStream;
  Stream<int>? _adminUnreadStream;
  int _adminUnreadCount = 0;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    try {
      _repository = widget.repository ?? AdminRepository();
      _itemsStream = _repository!.streamAllItems();
      _usersStream = _repository!.streamUserCount();
      _usersListStream = _repository!.streamUsers();
      _adminUnreadStream = _repository!.streamAdminUnreadCount();
    } catch (_) {
      _repository = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _guardRoute();
      _initProfile();
      _listenAdminUnread();
    });
  }

  @override
  void dispose() {
    _adminUnreadSub?.cancel();
    super.dispose();
  }

  StreamSubscription<int>? _adminUnreadSub;

  void _listenAdminUnread() {
    _adminUnreadSub = _adminUnreadStream?.listen((count) {
      if (!mounted) return;
      setState(() => _adminUnreadCount = count);
    });
  }

  /// Writes `isAdmin: true` to the admin's user document so the Firestore
  /// `isAdmin()` helper passes, enabling chat read/write access.
  Future<void> _initProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await DatabaseService().ensureAdminProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    } catch (e) {
      debugPrint('[AdminDashboard] _ensureAdminProfile error: $e');
    }
  }

  Future<void> _guardRoute() async {
    if (!_auth.isAdminAuthenticated) {
      if (_auth.isAuthenticated) {
        _goToUserDashboard();
      } else {
        _goToLogin();
      }
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      FadeThroughRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToUserDashboard() {
    Navigator.pushReplacement(
      context,
      FadeThroughRoute(
        builder: (_) => DashboardScreen(authService: widget.authService),
      ),
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      FadeThroughRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  void _selectSection(int index) {
    if (index == _sidebarSections.length - 1) {
      _signOut();
      return;
    }
    setState(() => _selectedIndex = index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static const _sidebarSections = <_NavItem>[
    _NavItem(label: 'Dashboard', icon: Icons.space_dashboard_rounded),
    _NavItem(label: 'Review Queue', icon: Icons.fact_check_rounded),
    _NavItem(label: 'Lost Items', icon: Icons.fmd_bad_rounded),
    _NavItem(label: 'Found Items', icon: Icons.inventory_2_rounded),
    _NavItem(label: 'Reports', icon: Icons.receipt_long_rounded),
    _NavItem(label: 'Users', icon: Icons.people_alt_rounded),
    _NavItem(label: 'Messages', icon: Icons.chat_bubble_rounded),
    _NavItem(label: 'Profile', icon: Icons.person_rounded),
    _NavItem(label: 'Settings', icon: Icons.settings_rounded),
    _NavItem(label: 'Logout', icon: Icons.logout_rounded, logout: true),
  ];

  @override
  Widget build(BuildContext context) {
    if (!_auth.isAdminAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final adminName = _adminName();
    final adminEmail = _adminEmail();

    final sections = _sidebarSections;
    final sidebar = _Sidebar(
      sections: sections,
      selectedIndex: _selectedIndex,
      onSelect: _selectSection,
      adminName: adminName,
      adminEmail: adminEmail,
      unreadCount: _adminUnreadCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        if (!wide) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Admin Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => _showNotice('Notifications'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _AvatarBadge(initial: adminName[0].toUpperCase(), size: 34),
                ),
              ],
            ),
            drawer: Drawer(child: sidebar),
            body: _buildSectionBody(context, sections, adminName),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              sidebar,
              Container(
                width: 1,
                color: AppColors.cardBorder,
              ),
              Expanded(child: _buildSectionBody(context, sections, adminName)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionBody(
    BuildContext context,
    List<_NavItem> sections,
    String adminName,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _DashboardOverview(
          adminName: adminName,
          itemsStream: _itemsStream,
          usersStream: _usersStream,
          repositoryAvailable: _repository != null,
          onNotice: _showNotice,
        );
      case 1:
        return AdminReviewQueueScreen(adminUid: _auth.currentUser?.uid ?? '');
      case 6:
        return AdminInboxScreen(adminUid: _auth.currentUser?.uid ?? '');
      case 5:
        return _UsersSection(usersStream: _usersListStream);
      case 7:
        return _AdminProfileSection(
          adminUid: _auth.currentUser?.uid ?? '',
          adminName: adminName,
          adminEmail: _adminEmail(),
        );
      case 8:
        return _SettingsSection(onNotice: _showNotice);
      default:
        final item = sections[_selectedIndex];
        return _SectionPlaceholder(
          icon: item.icon,
          title: item.label,
        );
    }
  }

  String _adminName() {
    final name = _auth.currentUser?.displayName?.trim();
    return (name == null || name.isEmpty) ? 'Admin' : name;
  }

  String _adminEmail() => _auth.currentUser?.email ?? '';

  void _showNotice(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, required this.icon, this.logout = false});

  final String label;
  final IconData icon;
  final bool logout;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
    required this.adminName,
    required this.adminEmail,
    this.unreadCount = 0,
  });

  final List<_NavItem> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String adminName;
  final String adminEmail;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const AppLogo(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADMIN PANEL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          adminEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < sections.length; i++) ...[
              if (i == sections.length - 1)
                const Divider(height: 24, indent: 20, endIndent: 20),
              _SidebarItem(
                item: sections[i],
                selected: selectedIndex == i,
                unreadCount: i == 6 ? unreadCount : 0, // Messages index = 6
                onTap: () => onSelect(i),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  _AvatarBadge(initial: adminName[0].toUpperCase(), size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.unreadCount = 0,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final color = item.logout
        ? AppColors.error
        : selected
            ? AppColors.primary
            : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Dashboard overview ─────────────────────────────────────────────────────

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.adminName,
    required this.itemsStream,
    required this.usersStream,
    required this.repositoryAvailable,
    required this.onNotice,
  });

  final String adminName;
  final Stream<List<LostFoundItem>>? itemsStream;
  final Stream<int>? usersStream;
  final bool repositoryAvailable;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final statCardWidth = w >= 1180
            ? (w - 48) / 4
            : w >= 640
                ? (w - 16) / 2
                : w;
        final chartCardWidth = w >= 1000 ? (w - 16) / 2 : w;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                adminName: adminName,
                onNotice: onNotice,
              ),
              const SizedBox(height: 20),
              if (!repositoryAvailable)
                const _UnavailableNotice(),
              if (itemsStream == null || usersStream == null) ...[
                const SizedBox(height: 16),
                const _EmptyPanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Live data unavailable',
                  message:
                      'Reports and user statistics could not be loaded right now.',
                ),
              ] else
                StreamBuilder<List<LostFoundItem>>(
                  stream: itemsStream,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <LostFoundItem>[];
                    final data = _DashboardData.fromItems(items);
                    return StreamBuilder<int>(
                      stream: usersStream,
                      builder: (context, usersSnapshot) {
                        final userCount = usersSnapshot.data ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _StatCard(
                                  width: statCardWidth,
                                  label: 'Lost Items',
                                  value: data.lost,
                                  icon: Icons.fmd_bad_rounded,
                                  color: AppColors.error,
                                  tint: AppColors.errorSurface,
                                  caption: 'total lost reports',
                                ),
                                _StatCard(
                                  width: statCardWidth,
                                  label: 'Found Items',
                                  value: data.found,
                                  icon: Icons.inventory_2_rounded,
                                  color: AppColors.success,
                                  tint: AppColors.successSurface,
                                  caption: 'total found reports',
                                ),
                                _StatCard(
                                  width: statCardWidth,
                                  label: 'Users',
                                  value: userCount,
                                  icon: Icons.people_alt_rounded,
                                  color: AppColors.primary,
                                  tint: AppColors.primarySurface,
                                  caption: 'registered accounts',
                                ),
                                _StatCard(
                                  width: statCardWidth,
                                  label: 'Pending Reports',
                                  value: data.pending,
                                  icon: Icons.pending_actions_rounded,
                                  color: AppColors.warning,
                                  tint: AppColors.warningSurface,
                                  caption: 'awaiting review',
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _ChartCard(
                                  width: chartCardWidth,
                                  title: 'Reports Overview',
                                  child: _TrendChart(data: data),
                                ),
                                _ChartCard(
                                  width: chartCardWidth,
                                  title: 'Reports by Category',
                                  child: _CategoryDonut(
                                    slices: data.categories,
                                    total: data.total,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _RecentReportsCard(
                              items: data.recent,
                              onNotice: onNotice,
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                SizedBox(
                                  width: chartCardWidth,
                                  child: const _AdminActionsCard(),
                                ),
                                SizedBox(
                                  width: chartCardWidth,
                                  child: const _TechStackCard(),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.adminName, required this.onNotice});

  final String adminName;
  final ValueChanged<String> onNotice;

  String get _today {
    final now = DateTime.now();
    return '${_monthAbbr[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome back, $adminName',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _today,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.surface,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.cardBorder),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onNotice('Notifications'),
                child: Ink(
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _AvatarBadge(initial: adminName[0].toUpperCase(), size: 40),
          ],
        ),
      ],
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live database is unavailable. Showing cached data.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard data ─────────────────────────────────────────────────────────

class _DayPoint {
  const _DayPoint(this.label, this.lost, this.found, this.resolved);

  final String label;
  final double lost;
  final double found;
  final double resolved;
}

class _CategorySlice {
  const _CategorySlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _DashboardData {
  _DashboardData({
    required this.lost,
    required this.found,
    required this.pending,
    required this.total,
    required this.recent,
    required this.trend,
    required this.categories,
  });

  factory _DashboardData.fromItems(List<LostFoundItem> items) {
    var lost = 0, found = 0, pending = 0;
    for (final item in items) {
      if (item.kind == ItemKind.lost) {
        lost++;
      } else {
        found++;
      }
      if (item.status == ItemStatus.open) pending++;
    }

    final recent = items.take(6).toList();
    return _DashboardData(
      lost: lost,
      found: found,
      pending: pending,
      total: items.length,
      recent: recent,
      trend: _buildTrend(items),
      categories: _buildCategories(items),
    );
  }

  final int lost;
  final int found;
  final int pending;
  final int total;
  final List<LostFoundItem> recent;
  final List<_DayPoint> trend;
  final List<_CategorySlice> categories;

  static const _weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static List<_DayPoint> _buildTrend(List<LostFoundItem> items) {
    final points = <_DayPoint>[];
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - 6);
    final lostByDay = <String, int>{};
    final foundByDay = <String, int>{};
    final resolvedByDay = <String, int>{};

    for (final item in items) {
      final day = item.createdAt;
      if (day == null) continue;
      final key = _dayKey(day);
      if (day.isBefore(start)) continue;
      if (item.kind == ItemKind.lost) {
        lostByDay[key] = (lostByDay[key] ?? 0) + 1;
      } else {
        foundByDay[key] = (foundByDay[key] ?? 0) + 1;
      }
      if (item.status == ItemStatus.matched) {
        resolvedByDay[key] = (resolvedByDay[key] ?? 0) + 1;
      }
    }

    for (var i = 0; i < 7; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      final key = _dayKey(day);
      points.add(
        _DayPoint(
          _weekday[day.weekday - 1],
          (lostByDay[key] ?? 0).toDouble(),
          (foundByDay[key] ?? 0).toDouble(),
          (resolvedByDay[key] ?? 0).toDouble(),
        ),
      );
    }
    return points;
  }

  static List<_CategorySlice> _buildCategories(List<LostFoundItem> items) {
    if (items.isEmpty) return const [];
    const palette = [
      Color(0xFF2563EB), Color(0xFF22C55E), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF14B8A6),
      Color(0xFFF97316), Color(0xFF0EA5E9), Color(0xFFEC4899),
      Color(0xFF64748B),
    ];

    final counts = <String, int>{};
    for (final item in items) {
      final category = _categoryOf(item);
      counts[category] = (counts[category] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.take(5).toList();
    final remainder = sorted.length > 5
        ? sorted.skip(5).fold<int>(0, (sum, e) => sum + e.value)
        : 0;

    final slices = <_CategorySlice>[];
    for (var i = 0; i < top.length; i++) {
      slices.add(
        _CategorySlice(top[i].key, top[i].value.toDouble(), palette[i]),
      );
    }
    if (remainder > 0) {
      slices.add(
        _CategorySlice('Other', remainder.toDouble(), palette[top.length]),
      );
    }
    return slices;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _categoryOf(LostFoundItem item) {
    final t = '${item.title} ${item.description}'.toLowerCase();
    if (t.contains('phone') ||
        t.contains('laptop') ||
        t.contains('computer') ||
        t.contains('earbud') ||
        t.contains('headphone') ||
        t.contains('charger') ||
        t.contains('tablet') ||
        t.contains('keyboard') ||
        t.contains('mouse') ||
        t.contains('cable') ||
        t.contains('flash drive') ||
        t.contains('usb') ||
        t.contains('electronic')) {
      return 'Electronics';
    }
    if (t.contains('wallet')) return 'Wallet';
    if (t.contains('key')) return 'Keys';
    if (t.contains('id ') ||
        t.contains('id card') ||
        t.contains('passport') ||
        t.contains('license') ||
        t.contains('card')) {
      return 'ID & Cards';
    }
    if (t.contains('book') ||
        t.contains('notebook') ||
        t.contains('textbook')) {
      return 'Books';
    }
    if (t.contains('bag') ||
        t.contains('backpack') ||
        t.contains('purse')) {
      return 'Bags';
    }
    if (t.contains('glass') ||
        t.contains('watch') ||
        t.contains('ring') ||
        t.contains('umbrella') ||
        t.contains('hat') ||
        t.contains('scarf') ||
        t.contains('jewelry') ||
        t.contains('accessory')) {
      return 'Accessories';
    }
    if (t.contains('shirt') ||
        t.contains('jacket') ||
        t.contains('shoe') ||
        t.contains('clothes') ||
        t.contains('uniform') ||
        t.contains('sweater') ||
        t.contains('hoodie') ||
        t.contains('socks')) {
      return 'Clothing';
    }
    if (t.contains('document') ||
        t.contains('paper') ||
        t.contains('envelope') ||
        t.contains('folder')) {
      return 'Documents';
    }
    return 'Other';
  }
}

// ── Stat cards ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.tint,
    required this.caption,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color tint;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Chart cards ───────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.width,
    required this.title,
    required this.child,
  });

  final double width;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final hasData = data.trend.any(
      (p) => p.lost > 0 || p.found > 0 || p.resolved > 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: hasData
              ? CustomPaint(
                  painter: _LineChartPainter(
                    points: data.trend,
                    series: const [
                      _SeriesSpec('Lost', AppColors.error),
                      _SeriesSpec('Found', AppColors.success),
                      _SeriesSpec('Resolved', AppColors.primary),
                    ],
                  ),
                )
              : const _EmptyChart(
                  icon: Icons.show_chart_rounded,
                  message: 'No report activity in the last 7 days yet.',
                ),
        ),
        if (hasData) ...[
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(color: AppColors.error, label: 'Lost'),
              _LegendDot(color: AppColors.success, label: 'Found'),
              _LegendDot(color: AppColors.primary, label: 'Resolved'),
            ],
          ),
        ],
      ],
    );
  }
}

class _SeriesSpec {
  const _SeriesSpec(this.label, this.color);

  final String label;
  final Color color;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.series});

  final List<_DayPoint> points;
  final List<_SeriesSpec> series;

  static const _padLeft = 32.0;
  static const _padBottom = 22.0;
  static const _padTop = 10.0;
  static const _padRight = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _padLeft - _padRight;
    final chartH = size.height - _padTop - _padBottom;
    if (chartW <= 0 || chartH <= 0) return;

    final maxVal = _chartMax();
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: AppColors.textTertiary,
      fontSize: 10,
    );

    for (var i = 0; i <= 4; i++) {
      final y = _padTop + chartH * (1 - i / 4);
      canvas.drawLine(
        Offset(_padLeft, y),
        Offset(size.width - _padRight, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: maxVal == 0 ? '0' : '${(maxVal * i / 4).round()}',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 6, y - tp.height / 2));
    }

    // X labels.
    final xStep = points.isEmpty ? chartW : chartW / points.length;
    for (var i = 0; i < points.length; i++) {
      final x = _padLeft + xStep * (i + 0.5);
      final tp = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, _padTop + chartH + 4),
      );
    }

    if (points.isEmpty) return;

    for (var s = 0; s < series.length; s++) {
      final path = Path();
      final dot = Paint()
        ..color = series[s].color
        ..style = PaintingStyle.fill;
      for (var i = 0; i < points.length; i++) {
        final value = _valueFor(points[i], s);
        final x = _padLeft + xStep * (i + 0.5);
        final y = maxVal == 0
            ? _padTop + chartH
            : _padTop + chartH * (1 - value / maxVal);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 2.6, dot);
      }
      final line = Paint()
        ..color = series[s].color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, line);
    }
  }

  double _valueFor(_DayPoint p, int index) {
    switch (index) {
      case 0:
        return p.lost;
      case 1:
        return p.found;
      default:
        return p.resolved;
    }
  }

  double _chartMax() {
    var m = 4.0;
    for (final p in points) {
      m = math.max(m, math.max(p.lost, math.max(p.found, p.resolved)));
    }
    if (m <= 4) return 4;
    final mag = math.pow(10, (math.log(m) / math.ln10).floor()).toDouble();
    final norm = m / mag;
    final nice = norm <= 1
        ? 1.0
        : norm <= 2
            ? 2.0
            : norm <= 5
                ? 5.0
                : 10.0;
    return nice * mag;
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.series != series;
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.slices, required this.total});

  final List<_CategorySlice> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty || total == 0) {
      return SizedBox(
        height: 160,
        child: const _EmptyChart(
          icon: Icons.pie_chart_outline_rounded,
          message: 'No reports to categorize yet.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = constraints.maxWidth >= 460 ? 170.0 : 130.0;
        return Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 14,
          children: [
            SizedBox(
              width: chartSize,
              height: chartSize,
              child: CustomPaint(
                painter: _DonutChartPainter(slices: slices),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth >= 460
                    ? constraints.maxWidth - chartSize - 20
                    : constraints.maxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final slice in slices)
                    _LegendRow(slice: slice, total: total),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.slices});

  final List<_CategorySlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 14;

    final track = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26;
    canvas.drawCircle(center, radius, track);

    var start = -math.pi / 2;
    const gap = 0.035;
    for (final slice in slices) {
      final sweep = 2 * math.pi * slice.value / _total();
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        paint,
      );
      start += sweep;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: '${_total().round()}',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  double _total() =>
      slices.fold(0.0, (sum, s) => sum + s.value);

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.total});

  final _CategorySlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (slice.value / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${slice.value.round()} · $percent%',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent reports ─────────────────────────────────────────────────────────

class _RecentReportsCard extends StatelessWidget {
  const _RecentReportsCard({required this.items, required this.onNotice});

  final List<LostFoundItem> items;
  final ValueChanged<String> onNotice;

  String _date(DateTime? d) {
    if (d == null) return '—';
    return '${_monthAbbr[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Reports',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onNotice('All reports'),
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
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No reports submitted yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 560),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _ReportRow(
                        item: items[i],
                        date: _date(items[i].createdAt),
                      ),
                      if (i != items.length - 1)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.item, required this.date});

  final LostFoundItem item;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 72, child: _TypeBadge(kind: item.kind)),
          SizedBox(
            width: 96,
            child: _StatusBadge(status: item.status),
          ),
          SizedBox(
            width: 70,
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _showDetails(context, item),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, LostFoundItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Type', item.kind == ItemKind.lost ? 'Lost' : 'Found'),
            _detailRow('Status', _statusLabel(item.status)),
            _detailRow(
              'Date',
              item.createdAt == null
                  ? '—'
                  : '${_monthAbbr[item.createdAt!.month - 1]} ${item.createdAt!.day}, ${item.createdAt!.year}',
            ),
            if (item.location != null) _detailRow('Location', item.location!),
            if (item.storageLocation != null)
              _detailRow('Storage', item.storageLocation!),
            if (item.description.isNotEmpty)
              _detailRow('Details', item.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(ItemStatus status) {
  switch (status) {
    case ItemStatus.open:
      return 'Pending';
    case ItemStatus.pendingVerification:
      return 'Pending Verification';
    case ItemStatus.verified:
      return 'Verified';
    case ItemStatus.matched:
      return 'Resolved';
    case ItemStatus.claimed:
      return 'Claimed';
    case ItemStatus.closed:
      return 'Closed';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.kind});

  final ItemKind kind;

  @override
  Widget build(BuildContext context) {
    final lost = kind == ItemKind.lost;
    final color = lost ? AppColors.error : AppColors.success;
    final tint = lost ? AppColors.errorSurface : AppColors.successSurface;
    return _Badge(
      label: lost ? 'Lost' : 'Found',
      color: color,
      tint: tint,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ItemStatus.open:
        return const _Badge(
          label: 'Pending',
          color: AppColors.warning,
          tint: AppColors.warningSurface,
        );
      case ItemStatus.pendingVerification:
        return const _Badge(
          label: 'Pending Verification',
          color: AppColors.warning,
          tint: AppColors.warningSurface,
        );
      case ItemStatus.verified:
        return const _Badge(
          label: 'Verified',
          color: AppColors.info,
          tint: AppColors.infoSurface,
        );
      case ItemStatus.matched:
        return const _Badge(
          label: 'Resolved',
          color: AppColors.info,
          tint: AppColors.infoSurface,
        );
      case ItemStatus.claimed:
        return const _Badge(
          label: 'Claimed',
          color: AppColors.success,
          tint: AppColors.successSurface,
        );
      case ItemStatus.closed:
        return const _Badge(
          label: 'Closed',
          color: AppColors.textSecondary,
          tint: AppColors.surfaceVariant,
        );
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.tint});

  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Admin actions ──────────────────────────────────────────────────────────

class _AdminActionsCard extends StatelessWidget {
  const _AdminActionsCard();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Admin Actions',
      icon: Icons.admin_panel_settings_rounded,
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            title: 'Approve / Reject Reports',
            subtitle: 'Review submitted lost & found reports.',
          ),
          _ActionTile(
            icon: Icons.edit_note_rounded,
            color: AppColors.warning,
            title: 'Edit / Delete Reports',
            subtitle: 'Manage incorrect or inappropriate reports.',
          ),
          _ActionTile(
            icon: Icons.handshake_rounded,
            color: AppColors.info,
            title: 'Mark as Claimed',
            subtitle: 'Close a found item once it is returned.',
          ),
          _ActionTile(
            icon: Icons.manage_accounts_rounded,
            color: AppColors.primary,
            title: 'Manage Users',
            subtitle: 'View users and manage admin actions.',
          ),
          _ActionTile(
            icon: Icons.summarize_rounded,
            color: AppColors.accent,
            title: 'Generate Reports',
            subtitle: 'Export stats, matches, activity and history.',
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title is coming soon.')),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Technology stack ───────────────────────────────────────────────────────

class _TechStackCard extends StatelessWidget {
  const _TechStackCard();

  static const _stack = <(IconData, String, String, Color)>[
    (Icons.flutter_dash_rounded, 'Flutter', 'Frontend', Color(0xFF3B82F6)),
    (
      Icons.verified_user_outlined,
      'Firebase Authentication',
      'Authentication',
      Color(0xFFF59E0B),
    ),
    (
      Icons.storage_rounded,
      'Cloud Firestore',
      'Database',
      Color(0xFF22C55E),
    ),
    (
      Icons.cloud_upload_outlined,
      'Firebase Storage',
      'File Storage',
      Color(0xFF8B5CF6),
    ),
    (
      Icons.notifications_active_outlined,
      'Firebase Cloud Messaging',
      'Notifications',
      Color(0xFFEF4444),
    ),
    (
      Icons.code_rounded,
      'Cloud Functions',
      'Backend Logic',
      Color(0xFF14B8A6),
    ),
    (
      Icons.auto_awesome_rounded,
      'Gemini API',
      'AI Matching',
      Color(0xFF0EA5E9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Technology Stack',
      icon: Icons.layers_rounded,
      child: Column(
        children: [
          for (final entry in _stack)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: entry.$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(entry.$1, size: 19, color: entry.$4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.$2,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          entry.$3,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Users section ──────────────────────────────────────────────────────────

class _UsersSection extends StatelessWidget {
  const _UsersSection({required this.usersStream});

  final Stream<List<Map<String, dynamic>>>? usersStream;

  @override
  Widget build(BuildContext context) {
    if (usersStream == null) {
      return const _SectionPlaceholder(
        icon: Icons.people_alt_rounded,
        title: 'Users',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Registered Users',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_rounded, size: 15, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text(
                          'All users',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: usersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _EmptyPanel(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load users',
                      message: snapshot.error.toString(),
                    );
                  }

                  final users = snapshot.data ?? const [];

                  if (users.isEmpty) {
                    return const _EmptyPanel(
                      icon: Icons.people_outline_rounded,
                      title: 'No users yet',
                      message: 'Registered users will appear here.',
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 44),
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  'User',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Email',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 60),
                            ],
                          ),
                        ),
                        for (var i = 0; i < users.length; i++) ...[
                          _UserRow(user: users[i]),
                          if (i != users.length - 1)
                            const Divider(height: 1, indent: 72, color: AppColors.border),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final displayName = (user['displayName'] as String?)?.trim();
    final email = (user['email'] as String?)?.trim() ?? '';
    final isAdmin = user['isAdmin'] as bool? ?? false;
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : email.isNotEmpty
            ? email.split('@').first
            : 'User';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isAdmin ? AppColors.primarySurface : AppColors.surfaceVariant,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isAdmin ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }
}

// ── Admin profile section ───────────────────────────────────────────────────

class _AdminProfileSection extends StatefulWidget {
  const _AdminProfileSection({
    required this.adminUid,
    required this.adminName,
    required this.adminEmail,
  });

  final String adminUid;
  final String adminName;
  final String adminEmail;

  @override
  State<_AdminProfileSection> createState() => _AdminProfileSectionState();
}

class _AdminProfileSectionState extends State<_AdminProfileSection> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  bool _saving = false;
  bool _editing = false;
  String? _photoUrl;
  int _reportsCount = 0;
  int _foundCount = 0;
  int _lostCount = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.adminName);
    _bioCtrl = TextEditingController(text: '');
    _loadProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (widget.adminUid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _nameCtrl.text = (data['displayName'] as String?) ?? widget.adminName;
          _bioCtrl.text = (data['bio'] as String?) ?? '';
          _photoUrl = data['photoUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('[AdminProfile] _loadProfile error: $e');
    }
  }

  Future<void> _loadStats() async {
    if (widget.adminUid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('items')
          .where('ownerUid', isEqualTo: widget.adminUid)
          .get();
      final items = snap.docs;
      setState(() {
        _reportsCount = items.length;
        _foundCount = items
            .where((d) => (d.data()['kind'] as String?) == 'found')
            .length;
        _lostCount = items
            .where((d) => (d.data()['kind'] as String?) == 'lost')
            .length;
      });
    } catch (e) {
      debugPrint('[AdminProfile] _loadStats error: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid)
          .update({
        'displayName': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await pickImageWithPreview(
      context,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;
    try {
      final ref = FirebaseStorage.instance
          .ref('profiles/${widget.adminUid}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid)
          .update({'photoUrl': url});
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Admin Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _photoUrl == null
                              ? AppColors.heroGradient
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _photoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: _photoUrl!,
                                  fit: BoxFit.cover,
                                  width: 96,
                                  height: 96,
                                  placeholder: (_, _) => const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.person_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.softShadow,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!_editing) ...[
                  Text(
                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Admin',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.adminEmail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_bioCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _bioCtrl.text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MetricCounter(
                          value: _reportsCount, label: 'Reports'),
                      const SizedBox(width: 32),
                      MetricCounter(
                          value: _foundCount, label: 'Found'),
                      const SizedBox(width: 32),
                      MetricCounter(
                          value: _lostCount, label: 'Lost'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _editing = true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tell us about yourself',
                      prefixIcon: Icon(Icons.info_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() => _editing = false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings with migration button ─────────────────────────────────────────

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({required this.onNotice});
  final ValueChanged<String> onNotice;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool _migrating = false;

  Future<void> _runMigration() async {
    setState(() => _migrating = true);
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('migrateModerationStatus').call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migration done: ${result.data}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.settings_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 280,
              child: ElevatedButton.icon(
                onPressed: _migrating ? null : _runMigration,
                icon: _migrating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(_migrating ? 'Migrating...' : 'Run Moderation Migration'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap once to add moderationStatus to all existing items.\nThis is safe to run multiple times.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section placeholders for the remaining sidebar items ───────────────────

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This admin section is coming soon.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
