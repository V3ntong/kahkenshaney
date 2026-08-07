import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../utils/page_transitions.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  String? _error;

  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetOtp(email);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        SharedAxisRoute(
          builder: (_) => OtpScreen(
            email: email,
            purpose: OtpPurpose.resetPassword,
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
      title: 'Forgot Password',
      subtitle:
          'Enter your registered email and we will send you a one-time '
          'verification code.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _emailController,
                label: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                onFieldSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 20),
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
          ),
        ),
      ],
    );
  }
}
