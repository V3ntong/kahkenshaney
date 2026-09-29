import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// A mixin that provides replay animation capabilities for count-up widgets.
///
/// Widgets using this mixin will re-animate when:
/// - The route becomes visible again (pop back, tab switch)
/// - The value changes while visible
mixin CountUpReplayMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription> _subscriptions = [];
  bool _isVisible = true;

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  /// Call this when the widget becomes visible (e.g., in didChangeDependencies)
  void registerVisibilityChange(VoidCallback onVisibilityChange) {
    // Subscribe to route changes using a RouteObserver pattern
    final route = ModalRoute.of(context);
    if (route != null) {
      // We can't directly listen to route changes, so we'll use
      // didChangeDependencies and a RouteObserver at the app level
      // For now, we'll use a simpler approach
    }

    // Listen to app lifecycle
    final binding = WidgetsBinding.instance;
    final lifecycleSub = binding
        .addObserver(_LifecycleObserver(onVisibilityChange))
        as StreamSubscription;
    _subscriptions.add(lifecycleSub);
  }

  void setVisible(bool visible) {
    _isVisible = visible;
  }

  bool get isVisible => _isVisible;
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.onChange);

  final VoidCallback onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onChange();
    }
  }
}

/// A wrapper to convert WidgetsBindingObserver to StreamSubscription
class _ObserverSubscription implements StreamSubscription<void> {
  _ObserverObserver(this.observer);

  final WidgetsBindingObserver observer;

  @override
  void onData(void Function(void) handleData) {}

  @override
  void onError(void Function(Object) handleError) {}

  @override
  void onDone(void Function() handleDone) {}

  @override
  void cancel() {
    WidgetsBinding.instance.removeObserver(observer);
  }

  @override
  void pause([Future<void> Function()? resumeSignal]) {}

  @override
  void resume() {}
}

/// A wrapper to convert WidgetsBindingObserver to StreamSubscription
class _ObserverSubscription implements StreamSubscription<void> {
  _ObserverSubscription(this.observer);

  final WidgetsBindingObserver observer;

  @override
  void onData(void Function(void) handleData) {}

  @override
  void onError(void Function(Object) handleError) {}

  @override
  void onDone(void Function() handleDone) {}

  @override
  void cancel() {
    WidgetsBinding.instance.removeObserver(observer);
  }

  @override
  void pause([Future<void> Function() resumeSignal]) {}

  @override
  void resume() {}
}

/// A replay token that changes when the widget should replay its animation.
///
/// This is a simple [ChangeNotifier] that other widgets can listen to.
class ReplayToken extends ChangeNotifier {
  int _token = 0;

  int get token => _token;

  void replay() {
    _token++;
    notifyListeners();
  }
}

/// A reusable count-up text widget with advanced features:
/// - Animates from [from] to [to] with spring-like easing
/// - Supports decimals, thousand separators, prefix/suffix
/// - Replays animation when page becomes visible again (tab switch, pop back)
/// - Animates from current displayed value when [to] changes
/// - Uses tabular figures to prevent digit jitter
/// - Respects "reduce motion" accessibility setting
class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.to,
    this.from = 0,
    this.duration = const Duration(milliseconds: 1500),
    this.delay = Duration.zero,
    this.decimals = 0,
    this.separator = ',',
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.replayToken,
    this.curve = Curves.easeOutCubic,
    this.semanticsLabel,
  });

  /// Target value to animate to
  final num to;

  /// Starting value (default 0)
  final num from;

  /// Animation duration
  final Duration duration;

  /// Delay before starting animation
  final Duration delay;

  /// Number of decimal places
  final int decimals;

  /// Thousand separator (e.g., ',' or ' ' or '')
  final String separator;

  /// Text to show before the number
  final String prefix;

  /// Text to show after the number
  final String suffix;

  /// Text style
  final TextStyle? style;

  /// Optional replay token - when this token changes, animation replays
  final ReplayToken? replayToken;

  /// Easing curve
  final Curve curve;

  /// Accessibility label
  final String? semanticsLabel;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with CountUpReplayMixin<CountUpText>, SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late num _currentValue;
  StreamSubscription<void>? _replaySubscription;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.from;

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: widget.from.toDouble(),
      end: widget.to.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _currentValue = _animation.value;
          });
        }
      });

    // Set up replay token listener
    if (widget.replayToken != null) {
      _replaySubscription = widget.replayToken!
          .addListener(_onReplayTokenChanged);
    }

    // Register visibility change for route/tab switches
    registerVisibilityChange(_onVisibilityChanged);

    _startAnimation();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.to != widget.to) {
      // Target value changed - animate from current displayed value
      _targetValue = widget.to;
      _startAnimation(fromCurrent: true);
    }

    if (oldWidget.replayToken != widget.replayToken) {
      _replaySubscription?.cancel();
      if (widget.replayToken != null) {
        _replaySubscription = widget.replayToken!
            .addListener(_onReplayTokenChanged);
      }
    }

    if (oldWidget.from != widget.from) {
      _currentValue = widget.from;
    }
  }

  void _onReplayTokenChanged() {
    if (mounted) {
      _startAnimation();
    }
  }

  void _onVisibilityChanged() {
    if (mounted && _isVisible) {
      _startAnimation();
    }
  }

  void _startAnimation({bool fromCurrent = false}) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      setState(() {
        _currentValue = widget.to;
      });
      return;
    }

    final startValue = fromCurrent ? _currentValue : widget.from;
    final endValue = widget.to;

    _controller
      ..reset()
      ..forward(from: 0);

    _animation = Tween<double>(
      begin: startValue.toDouble(),
      end: endValue.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _currentValue = _animation.value;
          });
        }
      });

    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward(from: 0);
        }
      });
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _replaySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(num value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    final intPart = absValue.truncate();
    final fracPart = absValue - intPart;

    // Format integer part with separator
    String intStr = intPart.toString();
    if (widget.separator.isNotEmpty && intStr.length > 3) {
      final buffer = StringBuffer();
      for (int i = intStr.length; i > 0; i -= 3) {
        final start = (i - 3).clamp(0, intStr.length);
        buffer.write(intStr.substring(start, i));
        if (i > 3) {
          buffer.write(widget.separator);
        }
      }
      intStr = buffer.toString().split('').reversed.join('');
    }

    // Format decimal part
    String result = intStr;
    if (widget.decimals > 0) {
      final fracStr = fracPart.toStringAsFixed(widget.decimals).substring(2);
      result = '$intStr.$fracStr';
    }

    if (isNegative) {
      result = '-$result';
    }

    return '${widget.prefix}$result${widget.suffix}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel ?? _formatNumber(_currentValue),
      child: ExcludeSemantics(
        child: Text(
          _formatNumber(_currentValue),
          style: (widget.style ?? const TextStyle()).copyWith(
            // Use tabular figures to prevent digit jitter
            fontFeatures: const [
              FontFeature.tabularFigures(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A version of CountUpText that works with an external [AnimationController]
/// for more complex orchestrations.
class ControlledCountUpText extends StatelessWidget {
  const ControlledCountUpText({
    super.key,
    required this.controller,
    required this.to,
    this.from = 0,
    this.decimals = 0,
    this.separator = ',',
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.curve = Curves.easeOutCubic,
    this.semanticsLabel,
  });

  final AnimationController controller;
  final num to;
  final num from;
  final int decimals;
  final String separator;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Curve curve;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(
      begin: from.toDouble(),
      end: to.toDouble(),
    ).animate(CurvedAnimation(parent: controller, curve: curve));

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return _buildNumber(animation.value);
      },
    );
  }

  Widget _buildNumber(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    final intPart = absValue.truncate();
    final fracPart = absValue - intPart;

    String intStr = intPart.toString();
    if (separator.isNotEmpty && intStr.length > 3) {
      final buffer = StringBuffer();
      for (int i = intStr.length; i > 0; i -= 3) {
        final start = (i - 3).clamp(0, intStr.length);
        buffer.write(intStr.substring(start, i));
        if (i > 3) {
          buffer.write(separator);
        }
      }
      intStr = buffer.toString().split('').reversed.join('');
    }

    String result = intStr;
    if (decimals > 0) {
      final fracStr = fracPart.toStringAsFixed(decimals).substring(2);
      result = '$intStr.$fracStr';
    }

    if (isNegative) {
      result = '-$result';
    }

    final text = '$prefix$result$suffix';

    return Semantics(
      label: semanticsLabel ?? text,
      child: ExcludeSemantics(
        child: Text(
          text,
          style: (style ?? const TextStyle()).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A global replay token for coordinating count-up animations across the app.
///
/// Use this to trigger replay of all count-up widgets when:
/// - User switches tabs (in HomePage)
/// - User navigates back to a page
/// - Data refreshes globally
class AppReplayToken extends ChangeNotifier {
  AppReplayToken._();

  static final AppReplayToken _instance = AppReplayToken._();

  static AppReplayToken get instance => _instance;

  int _token = 0;

  int get token => _token;

  void replayAll() {
    _token++;
    notifyListeners();
  }
}

/// Mixin for pages that want to trigger count-up replay on visibility change.
mixin CountUpReplayPageMixin<T extends StatefulWidget> on State<T> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger replay when page becomes active
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      AppReplayToken.instance.replayAll();
    }
  }
}