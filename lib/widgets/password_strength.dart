import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({
    super.key,
    required this.password,
    this.showEmptyLabel = false,
  });

  final String password;
  final bool showEmptyLabel;

  static const List<(double, Color)> _stops = [
    (0.0, Color(0xFFE03131)), // red
    (1.0, Color(0xFFF08C00)), // orange
    (2.0, Color(0xFFFCC419)), // yellow
    (3.0, Color(0xFF51CF66)), // light green
    (4.0, Color(0xFF0CA678)), // green
  ];

  static const List<String> _levels = [
    'Very Weak',
    'Weak',
    'Fair',
    'Good',
    'Strong',
  ];

  static Color _colorFor(double score) {
    final s = score.clamp(0.0, 4.0);
    for (var i = 0; i < _stops.length - 1; i++) {
      final (a, ca) = _stops[i];
      final (b, cb) = _stops[i + 1];
      if (s <= b) {
        final t = (s - a) / (b - a);
        return Color.lerp(ca, cb, t)!;
      }
    }
    return _stops.last.$2;
  }

  static String _levelName(int score) {
    if (score <= 0) return _levels.first;
    if (score >= _levels.length) return _levels.last;
    return _levels[score];
  }

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordStrength(password);
    final isEmpty = password.isEmpty;

    if (isEmpty) {
      return _Bar(
        value: 0,
        color: AppColors.border,
        label: showEmptyLabel ? 'Password strength' : null,
        showLabelColor: false,
      );
    }

    final target = score / 4;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final color = _colorFor(value * 4);
        return _Bar(
          value: value,
          color: color,
          label: 'Password strength: ${_levelName(score)}',
          showLabelColor: true,
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.color,
    required this.label,
    required this.showLabelColor,
  });

  final double value;
  final Color color;
  final String? label;
  final bool showLabelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label!,
              key: ValueKey<String>(label!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: showLabelColor ? color : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
