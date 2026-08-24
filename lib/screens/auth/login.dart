import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../utils/page_transitions.dart';
import '../admin_dashboard.dart';
import '../dashboard.dart';
import 'forgot_password.dart';
import 'signup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final result = await _auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case AuthSuccess():
        final home = _auth.isAdminAuthenticated
            ? AdminDashboardScreen(authService: widget.authService)
            : DashboardScreen(authService: widget.authService);
        Navigator.pushAndRemoveUntil(
          context,
          FadeThroughRoute(builder: (_) => home),
          (route) => false,
        );
      case AuthFailure(:final message):
        if (_isEmailNotFound(message)) {
          await showAppDialog(
            context,
            title: 'Email Not Found',
            message:
                'The email address you entered is not registered. Please check '
                'your email or create an account.',
            icon: Icons.mark_email_unread_outlined,
            iconColor: AppColors.error,
          );
        } else {
          setState(() => _error = message);
        }
    }
  }

  void _goToForgotPassword() {
    Navigator.push(
      context,
      SharedAxisRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      SharedAxisRoute(
        builder: (_) => SignupScreen(authService: widget.authService),
      ),
    );
  }

  /// Checks whether the error message indicates a missing account.
  bool _isEmailNotFound(String message) {
    final lower = message.toLowerCase();
    return lower.contains('no account found') ||
        lower.contains('not found') ||
        lower.contains('not registered');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: "Ready to find what you've been looking for?",
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "Don't have an account?",
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          AppTextButton(label: 'Sign Up', onPressed: _goToRegister),
        ],
      ),
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                showVisibilityToggle: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.loginPassword,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                AppAlert(message: _error!, type: AppAlertType.error),
                const SizedBox(height: 16),
              ],
              AppButton(
                label: 'Login',
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Center(
                child: AppTextButton(
                  label: 'Forgot Password?',
                  onPressed: _goToForgotPassword,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
