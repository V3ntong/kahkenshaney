import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared four-state view for stream-backed content.
///
/// waiting → spinner with a budget, error → message + Retry, empty → friendly
/// message, data → [builder].
///
/// A spinner is never the fallback for "no data" or "error": when the source
/// has produced nothing within [timeout] the error state is shown instead, and
/// activating Retry re-subscribes from scratch.
class AsyncStateView<T> extends StatefulWidget {
  const AsyncStateView({
    super.key,
    required this.stream,
    required this.builder,
    this.isEmpty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_rounded,
    this.errorTitle = 'Could not load',
    this.errorMessageBuilder,
    this.timeout = const Duration(seconds: 10),
    this.spinnerColor = AppColors.primary,
  });

  /// Source of the content. Re-created by the caller on retry.
  final Stream<T> stream;

  final Widget Function(BuildContext context, T data) builder;

  /// Whether [data] should render the empty state.
  final bool Function(T data)? isEmpty;

  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;

  final String errorTitle;

  /// Friendly, user-facing copy for [error]; the raw error is debugPrint'ed.
  final String? Function(Object error)? errorMessageBuilder;

  /// How long "waiting" may last before it turns into the error state.
  final Duration timeout;

  final Color spinnerColor;

  @override
  State<AsyncStateView<T>> createState() => _AsyncStateViewState<T>();
}

class _AsyncStateViewState<T> extends State<AsyncStateView<T>> {
  Timer? _budget;
  bool _timedOut = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startBudget();
  }

  @override
  void didUpdateWidget(covariant AsyncStateView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stream, widget.stream)) _startBudget();
  }

  @override
  void dispose() {
    _budget?.cancel();
    super.dispose();
  }

  void _startBudget() {
    _budget?.cancel();
    _timedOut = false;
    _budget = Timer(widget.timeout, () {
      if (!mounted) return;
      setState(() => _timedOut = true);
    });
  }

  void _retry() {
    setState(() {
      _timedOut = false;
      _generation++;
    });
    _startBudget();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      key: ValueKey<int>(_generation),
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _budget?.cancel();
          final error = snapshot.error!;
          debugPrint('[AsyncStateView] stream error: $error');
          return _Message(
            icon: Icons.cloud_off_rounded,
            iconColor: AppColors.error,
            title: widget.errorTitle,
            message:
                widget.errorMessageBuilder?.call(error) ??
                'Please check your connection and try again.',
            onRetry: _retry,
          );
        }

        if (snapshot.hasData) {
          _budget?.cancel();
          final data = snapshot.data as T;
          if (widget.isEmpty?.call(data) ?? false) {
            return _Message(
              icon: widget.emptyIcon,
              iconColor: AppColors.textTertiary,
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            );
          }
          return widget.builder(context, data);
        }

        if (_timedOut) {
          return _Message(
            icon: Icons.hourglass_empty_rounded,
            iconColor: AppColors.textTertiary,
            title: 'This is taking longer than expected',
            message: 'The connection did not respond. Try again.',
            onRetry: _retry,
          );
        }

        return Center(
          child: CircularProgressIndicator(color: widget.spinnerColor),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
