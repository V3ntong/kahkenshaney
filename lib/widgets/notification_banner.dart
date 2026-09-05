import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../screens/item_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Overlays an in-app banner when a push notification arrives while the app
/// is in the foreground.
///
/// Wraps [child] in a [Stack], listens to
/// [NotificationService.lastForegroundMessage], and slides a banner in from
/// the top. The banner auto-dismisses after a few seconds; tapping it opens
/// the related item (when the payload has a `relatedItemId`) or the
/// notifications screen.
class NotificationBannerHost extends StatefulWidget {
  const NotificationBannerHost({
    super.key,
    required this.child,
    this.userId,
  });

  final Widget child;

  /// The signed-in user's UID, used to open the notifications screen.
  final String? userId;

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  RemoteMessage? _message;
  bool _visible = false;
  Timer? _autoHideTimer;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.lastForegroundMessage.addListener(_onMessage);
  }

  @override
  void dispose() {
    NotificationService.lastForegroundMessage.removeListener(_onMessage);
    _autoHideTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  void _onMessage() {
    final message = NotificationService.lastForegroundMessage.value;
    if (message == null) return;

    _autoHideTimer?.cancel();
    _removeTimer?.cancel();
    setState(() {
      _message = message;
      _visible = true;
    });
    _autoHideTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    _autoHideTimer?.cancel();
    if (!mounted || _message == null) return;
    setState(() => _visible = false);
    _removeTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _open() async {
    final message = _message;
    _dismiss();
    if (message == null || widget.userId == null) return;

    final relatedItemId = message.data['relatedItemId'];
    if (relatedItemId is String && relatedItemId.isNotEmpty) {
      try {
        final item = await ItemRepository().getItem(relatedItemId);
        if (item != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
          );
          return;
        }
      } catch (e) {
        debugPrint('[NotificationBanner] Error opening item: $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          userId: widget.userId!,
          onNotificationTap: (itemId) {
            if (itemId != null && itemId.isNotEmpty) _openItem(itemId);
          },
        ),
      ),
    );
  }

  Future<void> _openItem(String itemId) async {
    try {
      final item = await ItemRepository().getItem(itemId);
      if (item != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
        );
      }
    } catch (e) {
      debugPrint('[NotificationBanner] Error opening item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Stack(
      children: [
        widget.child,
        if (message != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Backdrop blur on the app content while the banner is visible.
                  // Fades out smoothly with the banner slide animation.
                  if (_visible)
                    IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        builder: (context, blur, child) => Opacity(
                          opacity: 1.0 - blur,
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: blur * 6,
                              sigmaY: blur * 6,
                            ),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedSlide(
                    offset: _visible ? Offset.zero : const Offset(0, -1),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(message),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, -24 * (1 - t)),
                          child: child,
                        ),
                      ),
                      child: _bannerCard(message),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _bannerCard(RemoteMessage message) {
    final title = message.notification?.title ?? 'New Notification';
    final body = message.notification?.body ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: AppColors.surface,
        elevation: 6,
        shadowColor: const Color(0x14256EB3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismiss,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
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