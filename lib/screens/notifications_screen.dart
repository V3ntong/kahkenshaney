import 'package:flutter/material.dart';

import '../data/firestore/notification_service.dart';
import '../theme/app_theme.dart';

/// Notifications screen — shows all notifications for the user.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.userId,
    this.onNotificationTap,
  });

  final String userId;
  final void Function(String? relatedItemId)? onNotificationTap;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = NotificationService();
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.streamNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            );
          }

          final notifications = snapshot.data ?? const <AppNotification>[];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none_rounded, size: 36, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You\'ll be notified when there are updates.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Presentation-layer grouping only — the underlying stream/query
          // stays exactly as it was (newest first).
          final children = <Widget>[];
          for (final section in _groupByRecency(notifications)) {
            children.add(_SectionHeader(label: section.label));
            for (final notif in section.notifications) {
              children.add(
                _NotificationTile(
                  notification: notif,
                  onTap: () async {
                    await _service.markAsRead(widget.userId, notif.id);
                    widget.onNotificationTap?.call(notif.relatedItemId);
                  },
                ),
              );
            }
          }
          children.add(const SizedBox(height: 8));

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: children,
          );
        },
      ),
    );
  }

  /// Buckets notifications into Today / This week / Earlier, preserving the
  /// newest-first order the stream already provides.
  List<_NotificationSection> _groupByRecency(List<AppNotification> items) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    // Week starts on Monday so "This week" matches the usual calendar feel.
    final startOfWeek =
        startOfToday.subtract(Duration(days: startOfToday.weekday - 1));

    final today = <AppNotification>[];
    final thisWeek = <AppNotification>[];
    final earlier = <AppNotification>[];

    for (final n in items) {
      final at = n.createdAt;
      if (at == null) {
        today.add(n);
      } else if (!at.isBefore(startOfToday)) {
        today.add(n);
      } else if (!at.isBefore(startOfWeek)) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }

    return [
      if (today.isNotEmpty)
        _NotificationSection('Today', today),
      if (thisWeek.isNotEmpty)
        _NotificationSection('This week', thisWeek),
      if (earlier.isNotEmpty)
        _NotificationSection('Earlier', earlier),
    ];
  }
}

class _NotificationSection {
  const _NotificationSection(this.label, this.notifications);

  final String label;
  final List<AppNotification> notifications;
}

// ── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

// ── Notification Tile ─────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(notification.type);
    final color = _colorForType(notification.type);
    final unread = !notification.isRead;

    // Rounded-square, colour-coded container so notification types can be
    // scanned at a glance (green = approved/resolved, blue = submitted, ...).
    final leadingIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );

    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: unread
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                leadingIcon,
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
              ],
            )
          : leadingIcon,
      title: Text(
        notification.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: unread ? AppColors.textSecondary : AppColors.textTertiary,
          fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      trailing: notification.createdAt != null
          ? Text(
              _formatRelativeTime(notification.createdAt!),
              style: TextStyle(
                fontSize: 11,
                color: unread ? AppColors.primary : AppColors.textTertiary,
                fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
              ),
            )
          : null,
    );

    // Unread rows get a soft tint so they stand out from read history.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: unread
            ? AppColors.primarySurface.withValues(alpha: 0.9)
            : Colors.transparent,
      ),
      child: tile,
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'moderation_approved' => Icons.verified_rounded,
        'moderation_rejected' => Icons.cancel_rounded,
        'status_verified' => Icons.check_circle_rounded,
        'status_matched' => Icons.swap_horiz_rounded,
        'status_claimed' => Icons.check_circle_outline_rounded,
        'status_resolved' => Icons.task_alt_rounded,
        'claim_submitted' => Icons.assignment_turned_in_rounded,
        'match_suggestion' => Icons.auto_awesome_rounded,
        'match_confirmed' => Icons.link_rounded,
        'admin_invite' => Icons.admin_panel_settings_rounded,
        _ => Icons.notifications_none_rounded,
      };

  Color _colorForType(String type) => switch (type) {
        'moderation_approved' => AppColors.success,
        'moderation_rejected' => AppColors.error,
        'status_verified' => AppColors.success,
        'status_matched' => AppColors.success,
        'status_claimed' => AppColors.success,
        'status_resolved' => AppColors.success,
        'claim_submitted' => AppColors.info,
        'match_suggestion' => AppColors.primary,
        'match_confirmed' => AppColors.primary,
        'admin_invite' => AppColors.primary,
        _ => AppColors.info,
      };

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[time.month - 1]} ${time.day}';
  }
}
