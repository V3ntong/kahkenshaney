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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationTile(
                notification: notif,
                onTap: () async {
                  await _service.markAsRead(widget.userId, notif.id);
                  widget.onNotificationTap?.call(notif.relatedItemId);
                },
              );
            },
          );
        },
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

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        notification.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: notification.createdAt != null
          ? Text(
              _formatRelativeTime(notification.createdAt!),
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            )
          : null,
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'moderation_approved' => Icons.check_circle_rounded,
        'moderation_rejected' => Icons.cancel_rounded,
        'status_verified' => Icons.verified_rounded,
        'status_matched' => Icons.swap_horiz_rounded,
        'status_claimed' => Icons.check_circle_outline_rounded,
        _ => Icons.notifications_none_rounded,
      };

  Color _colorForType(String type) => switch (type) {
        'moderation_approved' => AppColors.success,
        'moderation_rejected' => AppColors.error,
        'status_verified' => AppColors.success,
        'status_matched' => AppColors.primary,
        'status_claimed' => AppColors.success,
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
