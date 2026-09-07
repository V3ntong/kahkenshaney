import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A centered, animated success overlay that scales/fades in a checkmark icon
/// with a short message beneath it. Auto-dismisses after [duration] or on tap.
///
/// Use via the static [show] helper:
/// ```dart
/// CenteredSuccessOverlay.show(context, message: 'Claim submitted for review');
/// ```
class CenteredSuccessOverlay {
  /// Shows a non-modal, auto-dismissing success overlay centered on screen.
  ///
  /// Returns an [OverlayEntry] that can be manually removed if needed.
  static OverlayEntry show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
    IconData icon = Icons.check_circle_rounded,
    Color iconColor = AppColors.success,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CenteredSuccessWidget(
        message: message,
        duration: duration,
        icon: icon,
        iconColor: iconColor,
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }
}

class _CenteredSuccessWidget extends StatefulWidget {
  const _CenteredSuccessWidget({
    required this.message,
    required this.duration,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
  });

  final String message;
  final Duration duration;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;

  @override
  State<_CenteredSuccessWidget> createState() => _CenteredSuccessWidgetState();
}

class _CenteredSuccessWidgetState extends State<_CenteredSuccessWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().whenComplete(() {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ColoredBox(
              color: Colors.black.withValues(alpha: 0.25 * _fadeAnim.value),
              child: Center(
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: _buildCard(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: widget.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 36,
              color: widget.iconColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
