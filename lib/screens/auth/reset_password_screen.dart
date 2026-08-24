import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/password_strength.dart';
import '../../utils/page_transitions.dart';
import '../dashboard.dart';
import 'login.dart';
import 'success_screen.dart';

enum PasswordResetMode {
  forgot,
  change,
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
    this.mode = PasswordResetMode.forgot,
    this.authService,
  });

  final String email;
  final String otp;
  final PasswordResetMode mode;
  final AuthService? authService;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (widget.mode == PasswordResetMode.change) {
        await _auth.changePassword(
          email: widget.email,
          otp: widget.otp,
          newPassword: _passwordController.text,
        );
      } else {
        await _auth.resetPassword(
          email: widget.email,
          otp: widget.otp,
          newPassword: _passwordController.text,
        );
      }
      if (!mounted) return;
      if (widget.mode == PasswordResetMode.change) {
        Navigator.pushReplacement(
          context,
          FadeThroughRoute(
            builder: (_) => SuccessScreen(
              title: 'Password Updated',
              message:
                  'Your password has been changed successfully. Keep it safe!',
              buttonLabel: 'Back to Dashboard',
              onPressed: (ctx) {
                Navigator.pushAndRemoveUntil(
                  ctx,
                  FadeThroughRoute(
                    builder: (_) =>
                        DashboardScreen(authService: widget.authService),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          FadeThroughRoute(
            builder: (_) => SuccessScreen(
              title: 'Password Reset',
              message:
                  'Your password has been updated successfully. You can now '
                  'sign in with your new password.',
              buttonLabel: 'Go to Login',
              onPressed: (ctx) {
                Navigator.pushReplacement(
                  ctx,
                  FadeThroughRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChange = widget.mode == PasswordResetMode.change;
    return AuthScaffold(
      title: isChange ? 'Set New Password' : 'Create New Password',
      subtitle: 'Enter a strong password for ${widget.email}.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _passwordController,
                label: 'New Password',
                hintText: 'Enter your new password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                showVisibilityToggle: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                validator: Validators.password,
              ),
              const SizedBox(height: 10),
              PasswordStrengthBar(password: _passwordController.text),
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmController,
                label: 'Confirm New Password',
                hintText: 'Re-enter your new password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                showVisibilityToggle: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) =>
                    Validators.confirmPassword(value, _passwordController.text),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                AppAlert(message: _error!, type: AppAlertType.error),
                const SizedBox(height: 16),
              ],
              AppButton(
                label: isChange ? 'Change Password' : 'Reset Password',
                icon: Icons.lock_reset_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
