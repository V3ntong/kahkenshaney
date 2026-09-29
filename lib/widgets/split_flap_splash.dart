import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A split-flap display splash screen that animates "KAH KEN SHA NEY"
/// with a space after every 3 letters (4 groups: KAH KEN SHA NEY).
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
  // The target text: "KAH KEN SHA NEY" (15 chars including 3 spaces)
  static const List<String> _targetChars = [
    'K', 'A', 'H', ' ', 'K', 'E', 'N', ' ', 'S', 'H', 'A', ' ', 'N', 'E', 'Y'
  ];
  
  // Timing constants
  static const int _totalDurationMs = 2400;  // Total animation duration
  static const int _staggerDelayMs = 100;    // Delay between each cell start
  static const int _cellDurationMs = 500;    // Duration of each cell's flip
  static const int _holdDurationMs = 500;    // Hold final text before completion
  
  // Animation
  late final AnimationController _controller;
  late final Animation<double> _progress;
  
  // Pre-computed scramble sequences for each cell (index 0-14)
  late final List<List<String>> _scrambleSequences;
  late final List<double> _settleProgress;
  
  bool _completed = false;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _precomputeScrambleSequences();
    // Don't start animation here - wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for disabled animations once after dependencies are available
    _animationsDisabled = MediaQuery.of(context).disableAnimations;
    if (!_controller.isAnimating && !_completed) {
      _startAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      duration: Duration(milliseconds: _totalDurationMs),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  void _precomputeScrambleSequences() {
    final rng = Random(0x4B4148); // "KAH" in hex as seed
    
    _scrambleSequences = List.generate(_targetChars.length, (index) {
      final targetChar = _targetChars[index];
      if (targetChar == ' ') {
        return [' '];
      }
      
      final sequenceLength = 8 + rng.nextInt(5); // 8-12 steps
      final sequence = List<String>.generate(sequenceLength, (i) {
        if (i == sequenceLength - 1) return targetChar;
        return String.fromCharCode(65 + rng.nextInt(26));
      });
      return sequence;
    });
    
    _settleProgress = List.generate(_targetChars.length, (index) {
      final startDelay = index * _staggerDelayMs;
      final settleTime = startDelay + _cellDurationMs;
      return (settleTime / _totalDurationMs).clamp(0.0, 1.0);
    });
  }

  Future<void> _startAnimation() async {
    if (_completed) return;
    
    if (_animationsDisabled) {
      // Set controller to end value so final text is displayed
      _controller.value = 1.0;
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && !_completed) {
        _completed = true;
        widget.onComplete();
      }
      return;
    }

    await _controller.forward();
    
    await Future.delayed(const Duration(milliseconds: _holdDurationMs));
    
    if (mounted && !_completed) {
      _completed = true;
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: _targetChars.asMap().entries.map((entry) {
                        final index = entry.key;
                        final char = entry.value;
                        
                        if (char == ' ') {
                          return const SizedBox(width: 24);
                        }
                        
                        return _SplitFlapLetter(
                          targetChar: char,
                          scrambleSequence: _scrambleSequences[index],
                          settleProgress: _settleProgress[index],
                          progress: _progress,
                          fontSize: 56.0,
                          textColor: widget.textColor,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Individual split-flap letter widget - pure stateless, driven by parent progress
class _SplitFlapLetter extends StatelessWidget {
  const _SplitFlapLetter({
    required this.targetChar,
    required this.scrambleSequence,
    required this.settleProgress,
    required this.progress,
    required this.fontSize,
    required this.textColor,
  });

  final String targetChar;
  final List<String> scrambleSequence;
  final double settleProgress;
  final Animation<double> progress;
  final double fontSize;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final p = progress.value;
        
        // Check if this cell should show its final character
        if (p >= settleProgress) {
          return _buildLetter(targetChar);
        }
        
        // Calculate which scramble character to show based on progress
        final cellStartProgress = (settleProgress - 1.0 / 15.0).clamp(0.0, 1.0);
        
        if (p <= cellStartProgress) {
          // Not started yet - show first scramble char
          return _buildLetter(scrambleSequence.first);
        }
        
        // Interpolate through scramble sequence
        final cellProgress = (p - cellStartProgress) / (settleProgress - cellStartProgress);
        final sequenceIndex = (cellProgress.clamp(0.0, 1.0) * (scrambleSequence.length - 1)).floor();
        final displayChar = scrambleSequence[sequenceIndex.clamp(0, scrambleSequence.length - 1)];
        
        // If we're in the flip phase (close to settle), do the split-flap rotation
        final distanceToSettle = settleProgress - p;
        if (distanceToSettle < 0.05 && distanceToSettle > 0) {
          final flipProgress = 1.0 - (distanceToSettle / 0.05);
          if (flipProgress < 0.5) {
            return _buildFlippingTop(scrambleSequence[sequenceIndex], targetChar, flipProgress * 2);
          } else {
            return _buildFlippingBottom(scrambleSequence[sequenceIndex], targetChar, (flipProgress - 0.5) * 2);
          }
        }
        
        return _buildLetter(displayChar);
      },
    );
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

  Widget _buildFlippingTop(String fromChar, String toChar, double progress) {
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(-progress * pi / 2),
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 0.5,
          child: _buildLetter(fromChar),
        ),
      ),
    );
  }

  Widget _buildFlippingBottom(String fromChar, String toChar, double progress) {
    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX((1 - progress) * pi / 2),
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.5,
          child: _buildLetter(toChar),
        ),
      ),
    );
  }
}

/// Splash screen that runs the split-flap animation and initialization in parallel.
/// Calls [onComplete] exactly once when both animation and initialization are done.
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
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final initFuture = widget.initializationFuture();

    await Future.wait([
      initFuture,
      Future.delayed(const Duration(milliseconds: 3500)),
    ]);

    if (mounted && !_navigated) {
      _navigated = true;
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplitFlapSplash(
      onComplete: () {
        if (mounted && !_navigated) {
          _navigated = true;
          widget.onComplete();
        }
      },
    );
  }
}