import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/auth_scaffold.dart';
import '../../utils/page_transitions.dart';
import 'otp_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.email,
    this.authService,
  });

  final String email;
  final AuthService? authService;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _loading = false;
  String? _error;

  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendChangePasswordOtp(widget.email);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        SharedAxisRoute(
          builder: (_) => OtpScreen(
            email: widget.email,
            purpose: OtpPurpose.changePassword,
            authService: widget.authService,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Change Password',
      subtitle:
          'For your security, we will email a 6-digit code to ${widget.email}. '
          'You can set a new password only after the code is confirmed.',
      children: [
        const Icon(Icons.shield_outlined, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        if (_error != null) ...[
          AppAlert(message: _error!, type: AppAlertType.error),
          const SizedBox(height: 16),
        ],
        AppButton(
          label: 'Send Verification Code',
          icon: Icons.send_rounded,
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }
}
