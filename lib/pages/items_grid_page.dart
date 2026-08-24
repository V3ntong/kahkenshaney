import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../screens/item_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/item_grid_card.dart';
import 'image_gallery_page.dart';

/// 2-column grid page for either Lost or Found items, backed by Firestore.
///
/// Shows a header banner with a CTA button, a 2-column [GridView], and
/// loading / error / empty states.
class ItemsGridPage extends StatelessWidget {
  const ItemsGridPage({
    super.key,
    required this.kind,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.ctaLabel,
    required this.onCtaTap,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'No items yet',
    this.emptyMessage = 'Items will appear here once reported.',
    this.onGalleryTap,
    this.repository,
  });

  final ItemKind kind;
  final String bannerTitle;
  final String bannerSubtitle;
  final String ctaLabel;
  final VoidCallback onCtaTap;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback? onGalleryTap;
  final ItemRepository? repository;

  @override
  Widget build(BuildContext context) {
    final stream = (repository ?? ItemRepository()).streamItems(kind: kind);
    final accent = kind == ItemKind.lost ? AppColors.error : AppColors.success;
    final accentSurface =
        kind == ItemKind.lost ? AppColors.errorSurface : AppColors.successSurface;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // ── Banner ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Banner(
              title: bannerTitle,
              subtitle: bannerSubtitle,
              ctaLabel: ctaLabel,
              onCtaTap: onCtaTap,
              onGalleryTap: onGalleryTap ??
                  () => Navigator.push(
                        context,
                        FadeSlideRoute(
                          builder: (_) => ImageGalleryPage(initialKind: kind),
                        ),
                      ),
              accent: accent,
              accentSurface: accentSurface,
              isLost: kind == ItemKind.lost,
            ),
          ),

          // ── Grid / States ──────────────────────────────────────
          StreamBuilder<List<LostFoundItem>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: _StateMessage(
                    icon: Icons.cloud_off_rounded,
                    color: AppColors.error,
                    title: 'Could not load items',
                    message: snapshot.error.toString(),
                  ),
                );
              }

              final items = snapshot.data ?? const <LostFoundItem>[];

              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGrid(
                    icon: emptyIcon,
                    color: accent,
                    title: emptyTitle,
                    message: emptyMessage,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ItemGridCard(
                      item: items[index],
                      onTap: () => Navigator.push(
                        context,
                        FadeSlideRoute(
                          builder: (_) => ItemDetailScreen(item: items[index]),
                        ),
                      ),
                    ),
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Banner ───────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCtaTap,
    required this.onGalleryTap,
    required this.accent,
    required this.accentSurface,
    required this.isLost,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCtaTap;
  final VoidCallback onGalleryTap;
  final Color accent;
  final Color accentSurface;
  final bool isLost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.95),
              accent.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLost ? Icons.fmd_bad_rounded : Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onGalleryTap,
                  tooltip: 'View image gallery',
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onCtaTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLost ? Icons.add_rounded : Icons.add_rounded,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ctaLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty ────────────────────────────────────────────────────────────────────

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error / generic message ──────────────────────────────────────────────────

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
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
      ),
    );
  }
}
