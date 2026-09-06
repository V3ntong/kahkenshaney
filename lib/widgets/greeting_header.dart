import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'text_animations.dart';

/// Premium dashboard header: large page title on the left;
/// notification icon and circular profile avatar on the right.
class GreetingHeader extends StatefulWidget {
  const GreetingHeader({
    super.key,
    this.userName,
    this.photoUrl,
    this.onNotifications,
    this.onAvatarTap,
    this.notificationCount = 0,
    this.animateReveal = false,
  });

  final String? userName;
  final String? photoUrl;
  final VoidCallback? onNotifications;
  final VoidCallback? onAvatarTap;
  final int notificationCount;

  /// When true, the username is displayed with the blur-to-focus animation.
  final bool animateReveal;

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
  String get _firstName {
    final name = widget.userName?.trim() ?? '';
    if (name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  String get _initial {
    final name = widget.userName?.trim() ?? '';
    if (name.isEmpty) return 'K';
    return name.characters.first.toUpperCase();
  }

  static const _headingStyle = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 28,
    color: AppColors.textPrimary,
    letterSpacing: 1.0,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: widget.animateReveal
                ? BlurRevealText(
                    text: _firstName.toUpperCase(),
                    duration: const Duration(milliseconds: 1000),
                    delay: const Duration(milliseconds: 300),
                    maxBlur: 10,
                    slideOffset: 16,
                    style: _headingStyle,
                  )
                : Text(
                    _firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _headingStyle,
                  ),
          ),
        ),
        _NotificationButton(
          count: widget.notificationCount,
          onTap: widget.onNotifications,
        ),
        const SizedBox(width: 12),
        _ProfileAvatar(
          initial: _initial,
          photoUrl: widget.photoUrl,
          onTap: widget.onAvatarTap,
        ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.softShadow,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 8,
                  top: 7,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: BoxConstraints(
                      minWidth: count < 10 ? 16 : 18,
                    ),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initial,
    this.photoUrl,
    this.onTap,
  });

  final String initial;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: photoUrl == null ? AppColors.heroGradient : null,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: AppColors.softShadow,
        ),
        child: ClipOval(
          child: photoUrl != null
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  width: 46,
                  height: 46,
                  placeholder: (_, _) => Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
