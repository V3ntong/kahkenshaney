import 'package:flutter/material.dart';

import '../../models/saved_account.dart';
import '../../services/auth_service.dart';
import '../../services/saved_accounts_store.dart';
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
  const LoginScreen({super.key, this.authService, this.savedAccountsStore});

  final AuthService? authService;

  /// Local store for the account switcher; injectable for tests.
  final SavedAccountsStore? savedAccountsStore;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  String? _error;
  List<SavedAccount> _accounts = const [];

  late final AuthService _auth = widget.authService ?? FirebaseAuthService();
  late final SavedAccountsStore _store =
      widget.savedAccountsStore ?? SavedAccountsStore();

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await _store.loadAccounts();
    if (!mounted) return;
    setState(() => _accounts = accounts);
  }

  /// Records the signed-in account on this device (profile info only — never
  /// passwords or tokens) so it appears in the switcher next time.
  Future<void> _persistCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _store.saveAccount(
        SavedAccount(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          lastLoginAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('[Login] failed to save account locally: $e');
    }
  }

  /// Selecting a saved account NEVER auto-logs-in: it prefills the email and
  /// asks for the password (lightweight re-authentication).
  void _selectSavedAccount(SavedAccount account) {
    _emailController.text = account.email;
    _passwordController.clear();
    _passwordFocus.requestFocus();
  }

  Future<void> _confirmRemoveAccount(SavedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved account?'),
        content: const Text(
          'This only clears the account from THIS device. Your account and '
          'data are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final remaining = await _store.removeAccount(account.uid);
    if (!mounted) return;
    setState(() => _accounts = remaining);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
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
        // Remember this account on-device for the login switcher.
        await _persistCurrentAccount();
        if (!mounted) return;
        await _auth.refreshAdminStatus();
        if (!mounted) return;
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
        // Saved accounts from this device (account switcher).
        if (_accounts.isNotEmpty) ...[
          _SavedAccountsSection(
            accounts: _accounts,
            onSelect: _selectSavedAccount,
            onRemove: _confirmRemoveAccount,
            onCreateNew: _goToRegister,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Use another profile',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
                focusNode: _passwordFocus,
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

// ─── Saved Accounts Section (account switcher) ───────────────────────────

class _SavedAccountsSection extends StatelessWidget {
  const _SavedAccountsSection({
    required this.accounts,
    required this.onSelect,
    required this.onRemove,
    required this.onCreateNew,
  });

  final List<SavedAccount> accounts;
  final ValueChanged<SavedAccount> onSelect;
  final ValueChanged<SavedAccount> onRemove;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAVED ACCOUNTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        ...accounts.map(
          (account) => _SavedAccountTile(
            account: account,
            onTap: () => onSelect(account),
            onRemove: () => onRemove(account),
          ),
        ),
        const SizedBox(height: 8),
        _CreateAccountTile(onTap: onCreateNew),
      ],
    );
  }
}

class _SavedAccountTile extends StatelessWidget {
  const _SavedAccountTile({
    required this.account,
    required this.onTap,
    required this.onRemove,
  });

  final SavedAccount account;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final photoUrl = account.photoUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySurface,
                  foregroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  onForegroundImageError:
                      photoUrl != null ? (_, __) {} : null,
                  child: Text(
                    account.initial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.maskedEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove saved account',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAccountTile extends StatelessWidget {
  const _CreateAccountTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Create new account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
