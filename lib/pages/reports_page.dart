import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../screens/item_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';

/// Reports tab — shows recently resolved items with claimant, reporter, and
/// approving admin details.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repo = ItemRepository();
  final _nameCache = <String, String>{};

  Future<String> _resolveName(String uid) async {
    if (uid.isEmpty) return 'Unknown';
    if (_nameCache.containsKey(uid)) return _nameCache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        _nameCache[uid] = 'Unknown';
        return 'Unknown';
      }
      final data = doc.data()!;
      final name = data['displayName'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        _nameCache[uid] = name.trim();
        return name.trim();
      }
      final email = data['email'] as String?;
      if (email != null && email.trim().isNotEmpty) {
        final fallback = email.trim().split('@').first;
        _nameCache[uid] = fallback;
        return fallback;
      }
      _nameCache[uid] = 'Unknown';
      return 'Unknown';
    } catch (_) {
      _nameCache[uid] = 'Unknown';
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Section header ──────────────────────────────────────
        FadeSlideInWidget(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recently Resolved Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Items that have been claimed and resolved',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Resolved items list ─────────────────────────────────
        Expanded(
          child: StreamBuilder<List<LostFoundItem>>(
            stream: _repo.streamResolvedItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.error),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not load resolved items',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <LostFoundItem>[];

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: AppColors.successSurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 36,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No resolved items yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Resolved items will appear here once claims are approved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FadeSlideInWidget(
                    delay: FadeSlideInWidget.staggerDelay(
                      index,
                      perItemMs: 60,
                      maxSpreadMs: 600,
                    ),
                    duration: const Duration(milliseconds: 380),
                    offset: 20,
                    child: _ResolvedItemCard(
                      item: item,
                      nameResolver: _resolveName,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(
                              item: item,
                              heroTagPrefix: 'reports',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Resolved Item Card ─────────────────────────────────────────────────────

class _ResolvedItemCard extends StatelessWidget {
  const _ResolvedItemCard({
    required this.item,
    required this.nameResolver,
    required this.onTap,
  });

  final LostFoundItem item;
  final Future<String> Function(String uid) nameResolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = item.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final imageUrl = item.displayUrl;
    final location = item.location?.isNotEmpty == true
        ? item.location!
        : item.storageLocation?.isNotEmpty == true
            ? item.storageLocation!
            : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: thumbnail + title + type badge
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(accent, isLost),
                          )
                        : _placeholder(accent, isLost),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLost ? 'LOST' : 'FOUND',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                          if (item.category != null && item.category!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category!,
                                style: const TextStyle(
                                  fontSize: 9,
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
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.success,
                ),
              ],
            ),

            // ── Location
            if (location != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),

            // ── Resolution details (async names)
            _DetailRow(
              label: 'Claimed by',
              uid: item.claimedBy ?? '',
              icon: Icons.how_to_reg_rounded,
              nameResolver: nameResolver,
            ),
            const SizedBox(height: 6),
            _DetailRow(
              label: 'Reported by',
              uid: item.reportedBy,
              icon: Icons.person_outline_rounded,
              nameResolver: nameResolver,
            ),
            if (item.resolvedByAdminId != null &&
                item.resolvedByAdminId!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(
                label: 'Approved by',
                uid: item.resolvedByAdminId!,
                icon: Icons.admin_panel_settings_outlined,
                nameResolver: nameResolver,
              ),
            ],
            if (item.resolvedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Resolved ${_formatDate(item.resolvedAt!)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _placeholder(Color accent, bool isLost) {
    return Container(
      color: accent.withValues(alpha: 0.1),
      child: Icon(
        isLost ? Icons.fmd_bad_rounded : Icons.inventory_2_rounded,
        color: accent,
        size: 24,
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = date.hour;
    final m = date.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour12:$m $period';
  }
}

// ── Detail Row with async name resolution ──────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.uid,
    required this.icon,
    required this.nameResolver,
  });

  final String label;
  final String uid;
  final IconData icon;
  final Future<String> Function(String uid) nameResolver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: FutureBuilder<String>(
            future: nameResolver(uid),
            builder: (context, snapshot) {
              final name = snapshot.data ?? '...';
              return Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
