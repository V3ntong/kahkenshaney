import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Rounded pill-shaped action button with a soft press-scale animation,
/// ripple feedback and a subtle shadow that lifts on tap.
///
/// Colours are fully configurable so the same component works on both light
/// surfaces and colourful hero cards (e.g. a white pill over a gradient).
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.background = AppColors.primary,
    this.foreground = Colors.white,
    this.borderColor,
    this.expanded = false,
    this.height = 48,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final bool expanded;
  final double height;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _pressed = false);
                HapticFeedback.lightImpact();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: BorderRadius.circular(999),
              border: widget.borderColor == null
                  ? null
                  : Border.all(color: widget.borderColor!),
              boxShadow: [
                BoxShadow(
                  color: widget.background.withValues(
                    alpha: _pressed ? 0.35 : 0.22,
                  ),
                  blurRadius: _pressed ? 6 : 12,
                  offset: Offset(0, _pressed ? 2 : 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _enabled ? () {} : null,
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                splashColor: Colors.white.withValues(alpha: 0.25),
                highlightColor: Colors.white.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisSize: widget.expanded
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: widget.foreground),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return widget.expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
