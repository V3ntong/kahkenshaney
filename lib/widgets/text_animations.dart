import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

// ─── Typewriter Text (Layout-Stable) ───────────────────────────────────────

/// Reveals text one character at a time with a blinking cursor.
/// Uses an invisible full-text placeholder to prevent layout shifting.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.speed = const Duration(milliseconds: 40),
    this.delay = Duration.zero,
    this.showCursor = true,
    this.cursorColor,
    this.onComplete,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration speed;
  final Duration delay;
  final bool showCursor;
  final Color? cursorColor;
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorCtrl;
  Timer? _typeTimer;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startTyping();
  }

  void _startTyping() {
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      _typeTimer = Timer.periodic(widget.speed, (timer) {
        if (_charCount >= widget.text.length) {
          timer.cancel();
          widget.onComplete?.call();
          return;
        }
        if (mounted) setState(() => _charCount++);
      });
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.substring(0, _charCount);
    final textAlign = widget.textAlign ?? TextAlign.left;

    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: widget.textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
          children: [
            // Invisible placeholder: reserves full final bounding box
            Text(
              widget.text,
              textAlign: textAlign,
              style: widget.style?.copyWith(color: Colors.transparent),
              maxLines: null,
            ),
            // Visible typed text (overlay)
            RichText(
              textAlign: textAlign,
              text: TextSpan(
                text: displayText,
                style: widget.style,
                children: [
                  if (widget.showCursor)
                    TextSpan(
                      text: '|',
                      style: TextStyle(
                        color: (widget.cursorColor ??
                                widget.style?.color ??
                                AppColors.primary)
                            .withValues(alpha: _cursorCtrl.value),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Blur Reveal Text (with slide-in) ──────────────────────────────────────

/// Text that transitions from blurry + offset to sharp, creating a
/// cinematic blur-to-focus entrance effect.
class BlurRevealText extends StatefulWidget {
  const BlurRevealText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxBlur = 12.0,
    this.slideOffset = 20.0,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final double maxBlur;
  final double slideOffset;
  final Duration duration;
  final Duration delay;

  @override
  State<BlurRevealText> createState() => _BlurRevealTextState();
}

class _BlurRevealTextState extends State<BlurRevealText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _blurAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _blurAnim = Tween<double>(begin: widget.maxBlur, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: _blurAnim.value,
            sigmaY: _blurAnim.value,
          ),
          child: SlideTransition(
            position: _slideAnim,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Text(widget.text, textAlign: widget.textAlign, style: widget.style),
            ),
          ),
        );
      },
    );
  }
}

// ─── Animated Auth Title ───────────────────────────────────────────────────

/// A reusable widget that wraps an auth screen title with blur-to-focus
/// animation (Bebas Neue font) and an optional subtitle with typewriter
/// animation (Lobster Two font).
class AnimatedAuthHeader extends StatefulWidget {
  const AnimatedAuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  State<AnimatedAuthHeader> createState() => _AnimatedAuthHeaderState();
}

class _AnimatedAuthHeaderState extends State<AnimatedAuthHeader> {
  @override
  Widget build(BuildContext context) {
    final titleStyle = widget.titleStyle ??
        GoogleFonts.bebasNeue(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          letterSpacing: 1.2,
        );

    final resolvedSubtitleStyle = widget.subtitleStyle ??
        GoogleFonts.lobsterTwo(
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.5,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlurRevealText(
          text: widget.title.toUpperCase(),
          textAlign: TextAlign.center,
          style: titleStyle,
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 800),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 10),
          TypewriterText(
            text: widget.subtitle!,
            textAlign: TextAlign.center,
            style: resolvedSubtitleStyle,
            delay: const Duration(milliseconds: 100),
            speed: const Duration(milliseconds: 2),
            showCursor: false,
            onComplete: () {},
          ),
        ],
      ],
    );
  }
}
