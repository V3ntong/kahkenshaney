import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ActionProgressState { idle, inProgress, success, error }

class ActionProgressBar extends StatefulWidget {
  const ActionProgressBar({
    super.key,
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
    this.onDismiss,
    this.successMessage = 'Success',
  });

  final ActionProgressState state;
  final double progress;
  final String? errorMessage;
  final VoidCallback? onDismiss;
  final String successMessage;

  @override
  State<ActionProgressBar> createState() => _ActionProgressBarState();
}

class _ActionProgressBarState extends State<ActionProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(ActionProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _handleStateChange();
    }
  }

  void _handleStateChange() {
    _autoDismissTimer?.cancel();

    switch (widget.state) {
      case ActionProgressState.idle:
        _slideController.reverse();
        break;
      case ActionProgressState.inProgress:
        _slideController.forward();
        break;
      case ActionProgressState.success:
        _slideController.forward();
        _autoDismissTimer = Timer(const Duration(milliseconds: 1500), () {
          widget.onDismiss?.call();
        });
        break;
      case ActionProgressState.error:
        _slideController.forward();
        break;
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == ActionProgressState.idle) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor()),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textColor(),
                      ),
                    ),
                  ),
                  if (widget.state == ActionProgressState.error &&
                      widget.onDismiss != null)
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: _buildProgressBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (widget.state) {
      case ActionProgressState.inProgress:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        );
      case ActionProgressState.success:
        return Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success);
      case ActionProgressState.error:
        return Icon(Icons.error_rounded, size: 18, color: AppColors.error);
      default:
        return const SizedBox.shrink();
    }
  }

  String _statusText() {
    switch (widget.state) {
      case ActionProgressState.inProgress:
        return 'Processing...';
      case ActionProgressState.success:
        return widget.successMessage;
      case ActionProgressState.error:
        return widget.errorMessage ?? 'Something went wrong';
      default:
        return '';
    }
  }

  Color _borderColor() {
    switch (widget.state) {
      case ActionProgressState.success:
        return AppColors.success.withValues(alpha: 0.3);
      case ActionProgressState.error:
        return AppColors.error.withValues(alpha: 0.3);
      default:
        return AppColors.border;
    }
  }

  Color _textColor() {
    switch (widget.state) {
      case ActionProgressState.success:
        return AppColors.success;
      case ActionProgressState.error:
        return AppColors.error;
      default:
        return AppColors.textPrimary;
    }
  }

  Widget _buildProgressBar() {
    final progress = widget.state == ActionProgressState.success
        ? 1.0
        : widget.progress.clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: _progressGradient(),
      ),
      child: FractionallySizedBox(
        widthFactor: progress,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: _progressGradient(),
          ),
        ),
      ),
    );
  }

  Gradient _progressGradient() {
    switch (widget.state) {
      case ActionProgressState.success:
        return const LinearGradient(colors: [AppColors.success, AppColors.success]);
      case ActionProgressState.error:
        return const LinearGradient(colors: [AppColors.error, AppColors.error]);
      default:
        return AppColors.primaryGradient;
    }
  }
}

class ActionController extends ChangeNotifier {
  ActionProgressState _state = ActionProgressState.idle;
  double _progress = 0.0;
  String? _errorMessage;
  String _successMessage = 'Success';

  OverlayEntry? _overlayEntry;

  ActionProgressState get state => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;

  void updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setInProgress({String message = 'Processing...'}) {
    _state = ActionProgressState.inProgress;
    _progress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  void setSuccess({String message = 'Success'}) {
    _state = ActionProgressState.success;
    _progress = 1.0;
    _successMessage = message;
    notifyListeners();
  }

  String get successMessage => _successMessage;

  void setError(String message) {
    _state = ActionProgressState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void dismiss() {
    _state = ActionProgressState.idle;
    _progress = 0.0;
    _errorMessage = null;
    _removeOverlay();
    notifyListeners();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }
}
