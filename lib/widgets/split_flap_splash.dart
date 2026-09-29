import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A split-flap display splash screen that animates "KAH KEN SHA NEY"
/// with a space after every 3 letters.
class SplitFlapSplash extends StatefulWidget {
  const SplitFlapSplash({
    super.key,
    required this.onComplete,
    this.backgroundColor = AppColors.background,
    this.textColor = AppColors.textPrimary,
  });

  final VoidCallback onComplete;
  final Color backgroundColor;
  final Color textColor;

  @override
  State<SplitFlapSplash> createState() => _SplitFlapSplashState();
}

class _SplitFlapSplashState extends State<SplitFlapSplash>
    with TickerProviderStateMixin {
  static const String _fullText = 'KAH KEN SHA NEY';
  static const List<String> _letters = [
    'K', 'A', 'H', ' ', 'K', 'E', 'N', ' ', 'S', 'H', 'A', ' ', 'N', 'E', 'Y'
  ];
  static const int _staggerDelayMs = 150;
  static const int _flipDurationMs = 400;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  late final List<Animation<double>> _topAnimations;
  late final List<Animation<double>> _bottomAnimations;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimation();
  }

  void _initAnimations() {
    _controllers = List.generate(_letters.length, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: _flipDurationMs),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    }).toList();

    _topAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
        ),
      );
    }).toList();

    _bottomAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    }).toList();
  }

  Future<void> _startAnimation() async {
    if (_isDisposed) return;

    // Check if animations should be disabled
    if (MediaQuery.of(context).disableAnimations) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isDisposed && mounted) {
        widget.onComplete();
      }
      return;
    }

    _isAnimating = true;

    // Stagger the animation start for each letter
    for (int i = 0; i < _controllers.length; i++) {
      if (_isDisposed) return;
      final delay = Duration(milliseconds: i * _staggerDelayMs);
      await Future.delayed(delay);
      if (!_isDisposed && mounted) {
        _controllers[i].forward();
      }
    }

    // Wait for the last animation to complete plus a brief pause
    await Future.delayed(const Duration(milliseconds: _flipDurationMs + 300));
    
    if (!_isDisposed && mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;
          final fontSize = isNarrow ? 36.0 : 56.0;
          final letterSpacing = isNarrow ? 4.0 : 8.0;

          // For narrow screens, split into two lines
          final lines = isNarrow
              ? [
                  _letters.sublist(0, 7).join(), // "KAH KEN"
                  _letters.sublist(7).join(),   // "SHA NEY"
                ]
              : [_fullText];

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: lines.map((line) {
                final chars = line.split('');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: chars.asMap().entries.map((entry) {
                      final index = entry.key;
                      final char = entry.value;
                      final globalIndex = lines.first == line
                          ? index
                          : 7 + index;
                      
                      if (char == ' ') {
                        return SizedBox(width: isNarrow ? 16 : 32);
                      }

                      return _SplitFlapLetter(
                        letter: char,
                        animation: _animations[globalIndex],
                        topAnimation: _topAnimations[globalIndex],
                        bottomAnimation: _bottomAnimations[globalIndex],
                        fontSize: fontSize,
                        textColor: widget.textColor,
                        isSpace: false,
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

/// Individual split-flap letter widget
class _SplitFlapLetter extends StatelessWidget {
  const _SplitFlapLetter({
    required this.letter,
    required this.animation,
    required this.topAnimation,
    required this.bottomAnimation,
    required this.fontSize,
    required this.textColor,
    required this.isSpace,
  });

  final String letter;
  final Animation<double> animation;
  final Animation<double> topAnimation;
  final Animation<double> bottomAnimation;
  final double fontSize;
  final Color textColor;
  final bool isSpace;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        
        if (progress == 0) {
          // Show random letters during flip
          return _buildRandomLetter();
        } else if (progress < 0.5) {
          // Top half flipping
          return _buildFlippingTop(progress * 2);
        } else if (progress < 1.0) {
          // Bottom half flipping
          return _buildFlippingBottom((progress - 0.5) * 2);
        } else {
          // Final letter
          return _buildFinalLetter();
        }
      },
    );
  }

  Widget _buildRandomLetter() {
    // Generate a deterministic random letter based on the target letter
    // This creates a consistent "random" sequence
    final random = Random(letter.codeUnitAt(0) * 1000);
    final randomChar = String.fromCharCode(65 + random.nextInt(26));
    return _buildLetter(randomChar);
  }

  Widget _buildFlippingTop(double progress) {
    // Top half rotates from 0 to -90 degrees
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(-progress * pi / 2),
      child: _buildLetterHalf(letter, isTop: true),
    );
  }

  Widget _buildFlippingBottom(double progress) {
    // Bottom half rotates from 90 to 0 degrees
    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX((1 - progress) * pi / 2),
      child: _buildLetterHalf(letter, isTop: false),
    );
  }

  Widget _buildFinalLetter() {
    return _buildLetter(letter);
  }

  Widget _buildLetter(String char) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        char,
        style: TextStyle(
          fontFamily: 'BebasNeue',
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: textColor,
          letterSpacing: 0,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildLetterHalf(String char, {required bool isTop}) {
    return ClipRect(
      child: Align(
        alignment: isTop ? Alignment.bottomCenter : Alignment.topCenter,
        heightFactor: 0.5,
        child: _buildLetter(char),
      ),
    );
  }
}

/// Splash screen that runs Firebase initialization in parallel with the animation
class SplitFlapSplashScreen extends StatefulWidget {
  const SplitFlapSplashScreen({
    super.key,
    required this.initializationFuture,
    required this.onComplete,
  });

  final Future<void> Function() initializationFuture;
  final VoidCallback onComplete;

  @override
  State<SplitFlapSplashScreen> createState() => _SplitFlapSplashScreenState();
}

class _SplitFlapSplashScreenState extends State<SplitFlapSplashScreen> {
  bool _initComplete = false;
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();
    _runParallel();
  }

  Future<void> _runParallel() async {
    // Run Firebase initialization and minimum splash duration in parallel
    final initFuture = widget.initializationFuture();
    const minSplashDuration = Duration(milliseconds: 3000);

    await Future.wait([
      initFuture,
      Future.delayed(minSplashDuration),
    ]);

    if (mounted) {
      setState(() {
        _initComplete = true;
      });
    }
  }

  void _onSplashComplete() {
    if (mounted && _initComplete) {
      widget.onComplete();
    } else if (mounted) {
      setState(() {
        _splashComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplitFlapSplash(
      onComplete: _onSplashComplete,
    );
  }
}