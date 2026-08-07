import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Floating bottom navigation with an **animated sliding pill** indicator,
/// icon scale transition, label fade, haptic feedback, and a subtle bounce
/// on tap.
///
/// The pill slides smoothly between tabs using [TweenAnimationBuilder]
/// so it stays buttery at 60fps without a dedicated [AnimationController].
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.fmd_bad_rounded, Icons.fmd_bad_outlined, 'Lost'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Reports'),
    (Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Found'),
    (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          height: 60,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _tabs.length;
              return Stack(
                children: [
                  // ── Sliding pill indicator ──────────────────────
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: selectedIndex * tabWidth,
                    ),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (_, offset, child) {
                      return Positioned(
                        left: offset + 4,
                        top: 4,
                        bottom: 4,
                        width: tabWidth - 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    },
                  ),

                  // ── Tab items ──────────────────────────────────
                  Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        _NavItem(
                          icon: _tabs[i].$1,
                          outlineIcon: _tabs[i].$2,
                          label: _tabs[i].$3,
                          selected: selectedIndex == i,
                          onTap: () => onSelected(i),
                        ),
                    ],
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
    required this.icon,
    required this.outlineIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData outlineIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: _AnimatedNavItem(
          selected: selected,
          icon: icon,
          outlineIcon: outlineIcon,
          label: label,
        ),
      ),
    );
  }
}

/// Animates icon scale, icon color, and label opacity when [selected] changes.
class _AnimatedNavItem extends StatelessWidget {
  const _AnimatedNavItem({
    required this.selected,
    required this.icon,
    required this.outlineIcon,
    required this.label,
  });

  final bool selected;
  final IconData icon;
  final IconData outlineIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: selected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        // Interpolate icon size: 22 → 24 on select
        final iconSize = 22 + 2 * value;
        // Interpolate color
        final color = Color.lerp(AppColors.textTertiary, AppColors.primary, value)!;
        // Label opacity: fade in on select
        final labelOpacity = value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 0.92 + 0.08 * value,
              child: Icon(
                value > 0.5 ? icon : outlineIcon,
                size: iconSize,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Opacity(
              opacity: labelOpacity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
