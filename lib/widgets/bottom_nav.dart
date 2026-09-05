import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A single destination in the floating pill navigation bar.
class BottomNavTab {
  const BottomNavTab({
    required this.label,
    required this.icon,
    required this.outlineIcon,
  });

  final String label;

  /// Filled icon — shown inside the raised accent badge when selected.
  final IconData icon;

  /// Outlined icon — shown when the tab is inactive.
  final IconData outlineIcon;
}

/// Floating, rounded "pill" bottom navigation.
///
/// The bar is a near-black capsule that floats above the bottom edge with
/// margin on all sides. The active tab is rendered as a filled circular badge
/// in the accent color that pops slightly above the bar line; inactive tabs
/// are plain muted icons with no background. Visual labels are hidden but
/// exposed to screen readers via [Semantics] and long-press [Tooltip]s.
///
/// Everything visual is configurable: [tabs], [accentColor], [barColor],
/// [inactiveIconColor], [badgeColor] and per-tab [badges] (e.g. unread
/// counts / notification indicators).
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.tabs = defaultTabs,
    this.accentColor = defaultAccentColor,
    this.barColor = defaultBarColor,
    this.inactiveIconColor = defaultInactiveIconColor,
    this.badgeColor = AppColors.error,
    this.badges = const {},
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The navigation destinations, in order. Defaults to the app's five core
  /// tabs (Home, Lost, Reports, Found, Messages).
  final List<BottomNavTab> tabs;

  /// Color of the raised active-tab badge (orange in the reference design).
  final Color accentColor;

  /// Solid near-black background of the pill.
  final Color barColor;

  /// Muted color for inactive icons.
  final Color inactiveIconColor;

  /// Color of the small contextual count pills (unread/notification badges).
  final Color badgeColor;

  /// Contextual badge counts keyed by tab index (e.g. `{4: 3}` shows a "3"
  /// pill on the Messages tab). Counts of zero are hidden.
  final Map<int, int> badges;

  static const Color defaultAccentColor = AppColors.navigationActive;
  static const Color defaultBarColor = AppColors.navigationSurface;
  static const Color defaultInactiveIconColor = AppColors.navigationInactive;

  static const List<BottomNavTab> defaultTabs = [
    BottomNavTab(
      label: 'Home',
      icon: Icons.home_rounded,
      outlineIcon: Icons.home_outlined,
    ),
    BottomNavTab(
      label: 'Lost',
      icon: Icons.fmd_bad_rounded,
      outlineIcon: Icons.fmd_bad_outlined,
    ),
    BottomNavTab(
      label: 'Reports',
      icon: Icons.receipt_long_rounded,
      outlineIcon: Icons.receipt_long_outlined,
    ),
    BottomNavTab(
      label: 'Found',
      icon: Icons.inventory_2_rounded,
      outlineIcon: Icons.inventory_2_outlined,
    ),
    BottomNavTab(
      label: 'Messages',
      icon: Icons.chat_bubble_rounded,
      outlineIcon: Icons.chat_bubble_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // SafeArea bottom inset keeps the pill clear of the home indicator/notch
    // on both iOS and Android. The 16px top padding is the headroom the
    // raised active badge pops into, so it never covers page content above.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(32),
            border: const Border.fromBorderSide(
              BorderSide(color: AppColors.navigationBorder),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / tabs.length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Positioned(
                      left: i * slotWidth,
                      width: slotWidth,
                      top: 0,
                      bottom: 0,
                      child: _NavItem(
                        tab: tabs[i],
                        selected: selectedIndex == i,
                        badgeCount: badges[i] ?? 0,
                        accentColor: accentColor,
                        inactiveIconColor: inactiveIconColor,
                        badgeColor: badgeColor,
                        barColor: barColor,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.badgeCount,
    required this.accentColor,
    required this.inactiveIconColor,
    required this.badgeColor,
    required this.barColor,
    required this.onTap,
  });

  final BottomNavTab tab;
  final bool selected;
  final int badgeCount;
  final Color accentColor;
  final Color inactiveIconColor;
  final Color badgeColor;
  final Color barColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tab.label,
      button: true,
      selected: selected,
      hint: 'Switches to the ${tab.label} tab',
      child: Tooltip(
        message: tab.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: TweenAnimationBuilder<double>(
            // 0 = inactive, 1 = active. Drives the icon lift + color fill.
            tween: Tween(begin: 0, end: selected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // ── Raised accent circle (active state) ─────────
                  // Built only while animating/active so the tree holds a
                  // single accent badge (the selected tab's).
                  if (t > 0)
                    Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -16 * t),
                        child: Transform.scale(
                          scale: 0.4 + 0.6 * t,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              tab.icon,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Plain outlined icon (inactive state) ────────
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 - 0.15 * t,
                      child: Icon(
                        tab.outlineIcon,
                        size: 24,
                        color: inactiveIconColor,
                      ),
                    ),
                  ),

                  // ── Contextual count pill (unread/notifications) ─
                  if (badgeCount > 0)
                    Positioned(
                      top: 0,
                      right: 6,
                      child: _CountBadge(
                        count: badgeCount,
                        color: badgeColor,
                        borderColor: barColor,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.color,
    required this.borderColor,
  });

  final int count;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
