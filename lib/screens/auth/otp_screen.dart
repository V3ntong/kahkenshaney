import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/cooldown_timer.dart';
import '../../utils/page_transitions.dart';
import '../../utils/validators.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/otp_input.dart';
import '../../data/firestore/database_service.dart';
import '../dashboard.dart';
import 'reset_password_screen.dart';

enum OtpPurpose {
  verifyEmail,
  resetPassword,
  changePassword,
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.purpose,
    this.fullName,
    this.password,
    this.authService,
  });

  final String email;
  final OtpPurpose purpose;
  final String? fullName;
  final String? password;
  final AuthService? authService;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _cooldownDuration = Duration(seconds: 60);

  late final CooldownTimer _cooldown;
  Timer? _ticker;
  String _code = '';
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    _cooldown = CooldownTimer(duration: _cooldownDuration);
    _cooldown.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _error = null);
    final validationError = Validators.otp(_code);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    if (_verifying) return;

    setState(() => _verifying = true);
    try {
      switch (widget.purpose) {
        case OtpPurpose.verifyEmail:
          await _auth.verifyEmailOtp(email: widget.email, otp: _code);
          final registerResult = await _auth.register(
            fullName: widget.fullName ?? '',
            email: widget.email,
            password: widget.password ?? '',
          );
          if (!mounted) return;
          if (registerResult is AuthFailure) {
            setState(() => _error = registerResult.message);
            return;
          }
          final user = _auth.currentUser;
          if (user != null) {
            try {
              await DatabaseService().createUserProfile(
                uid: user.uid,
                email: widget.email,
                displayName: widget.fullName ?? '',
              );
            } catch (_) {
              // Profile creation is best-effort — account is already active.
            }
          }
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            FadeThroughRoute(
              builder: (_) => DashboardScreen(authService: widget.authService),
            ),
            (route) => false,
          );
        case OtpPurpose.resetPassword:
          await _auth.verifyPasswordResetOtp(email: widget.email, otp: _code);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            SharedAxisRoute(
              builder: (_) => ResetPasswordScreen(
                email: widget.email,
                otp: _code,
                authService: widget.authService,
              ),
            ),
          );
        case OtpPurpose.changePassword:
          await _auth.verifyChangePasswordOtp(email: widget.email, otp: _code);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            SharedAxisRoute(
              builder: (_) => ResetPasswordScreen(
                email: widget.email,
                otp: _code,
                mode: PasswordResetMode.change,
                authService: widget.authService,
              ),
            ),
          );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[OtpScreen] _verify unexpected error: $e');
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown.isActive || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      switch (widget.purpose) {
        case OtpPurpose.verifyEmail:
          await _auth.resendSignupOtp(widget.email);
        case OtpPurpose.resetPassword:
          await _auth.sendPasswordResetOtp(widget.email);
        case OtpPurpose.changePassword:
          await _auth.sendChangePasswordOtp(widget.email);
      }
      if (!mounted) return;
      _cooldown.start();
      showAppSnackBar(context, 'A new code has been sent to your email.');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _resendLabel {
    if (_resending) return 'Resending...';
    if (_cooldown.isActive) {
      final seconds = _cooldown.remainingSeconds;
      final minutes = seconds ~/ 60;
      final secs = (seconds % 60).toString().padLeft(2, '0');
      return 'Resend in $minutes:$secs';
    }
    return 'Resend Code';
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Enter Verification Code',
      subtitle:
          'We sent a 6-digit code to ${widget.email}. The code expires in '
          '5 minutes.',
      children: [
        OtpInput(
          onCompleted: (code) {
            setState(() => _code = code);
            _verify();
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: Text(
            'The code is single-use and expires after 5 minutes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          AppAlert(message: _error!, type: AppAlertType.error),
          const SizedBox(height: 16),
        ],
        AppButton(
          label: 'Verify Code',
          icon: Icons.verified_rounded,
          loading: _verifying,
          onPressed: _verify,
        ),
        const SizedBox(height: 12),
        Center(
          child: AppTextButton(
            label: _resendLabel,
            loading: _resending,
            onPressed: (_cooldown.isActive || _resending) ? null : _resend,
          ),
        ),
      ],
    );
  }
}
