import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth/change_password_screen.dart';
import 'auth/login.dart';
import 'auth/terms_conditions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _itemMatchAlerts = true;
  bool _chatMessages = true;

  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('preferences')
          .doc('notifications')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _pushNotifications = data['pushNotifications'] ?? true;
          _itemMatchAlerts = data['itemMatchAlerts'] ?? true;
          _chatMessages = data['chatMessages'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _updatePreference(String key, bool value) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('preferences')
          .doc('notifications')
          .set({key: value}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final deleteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('Delete Account')),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'This action is permanent and cannot be undone. All your data will be deleted:\n\n'
                      '• Your profile and account data\n'
                      '• All posted items and reports\n'
                      '• Chat messages and history\n'
                      '• Saved preferences',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your password to confirm:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Your password',
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password is required' : null,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Type DELETE to confirm:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: deleteController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                    ],
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      prefixIcon: Icon(Icons.keyboard_alt_outlined, size: 18),
                    ),
                    validator: (v) =>
                        (v != 'DELETE') ? 'Type exactly DELETE to confirm' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                deleteController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);
                      final success = await _deleteAccount(
                        password: passwordController.text,
                      );
                      if (!ctx.mounted) return;
                      passwordController.dispose();
                      deleteController.dispose();
                      Navigator.pop(ctx);
                      if (success && mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _deleteAccount({required String password}) async {
    final user = _user;
    if (user == null || user.email == null) return false;

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      final prefs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preferences')
          .get();
      for (final doc in prefs.docs) {
        await doc.reference.delete();
      }

      await user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to delete account.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Incorrect password. Please try again.';
      } else if (e.code == 'requires-recent-login') {
        msg = 'Please log in again and try deleting your account.';
      } else if (e.code == 'user-not-found') {
        msg = 'User account not found.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account. Please try again.')),
        );
      }
      return false;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await (widget.authService ?? FirebaseAuthService()).signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Account'),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.key_rounded,
                  label: 'Change Password',
                  onTap: () {
                    final email = _user?.email ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePasswordScreen(
                          email: email,
                          authService: widget.authService,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete Account',
                  danger: true,
                  onTap: _showDeleteAccountDialog,
                ),

                const SizedBox(height: 28),
                _SectionHeader(title: 'Preferences'),
                const SizedBox(height: 10),
                _PreferenceSwitch(
                  icon: Icons.notifications_active_rounded,
                  label: 'Push Notifications',
                  value: _pushNotifications,
                  onChanged: (v) {
                    setState(() => _pushNotifications = v);
                    _updatePreference('pushNotifications', v);
                  },
                ),
                const SizedBox(height: 8),
                _PreferenceSwitch(
                  icon: Icons.search_rounded,
                  label: 'Item Match Alerts',
                  value: _itemMatchAlerts,
                  onChanged: (v) {
                    setState(() => _itemMatchAlerts = v);
                    _updatePreference('itemMatchAlerts', v);
                  },
                ),
                const SizedBox(height: 8),
                _PreferenceSwitch(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat Messages',
                  value: _chatMessages,
                  onChanged: (v) {
                    setState(() => _chatMessages = v);
                    _updatePreference('chatMessages', v);
                  },
                ),

                const SizedBox(height: 28),
                _SectionHeader(title: 'Legal'),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
                    );
                  },
                ),

                const SizedBox(height: 28),
                _SectionHeader(title: 'Support'),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'Contact Support',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.report_outlined,
                  label: 'Report a Problem',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactSupportScreen(
                          initialSubject: 'Report a Problem',
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),
                _SectionHeader(title: 'About'),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.info_outline_rounded,
                  label: 'App Name',
                  value: 'KAH KEN SHA NEY',
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  icon: Icons.android_rounded,
                  label: 'Version',
                  value: '1.0.0+1',
                ),

                const SizedBox(height: 28),
                _SectionHeader(title: 'Session'),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  danger: true,
                  onTap: _showLogoutDialog,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AppColors.error : AppColors.textPrimary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last updated: September 2025',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                _PrivacySection(
                  heading: '1. Information We Collect',
                  body:
                      'When you use KAH KEN SHA NEY, we collect information you '
                      'provide directly, including your name, email address, '
                      'phone number, and profile photo. We also collect '
                      'information about lost and found items you report, '
                      'including images and descriptions.',
                ),
                _PrivacySection(
                  heading: '2. How We Use Your Information',
                  body:
                      'We use your information to provide and improve our '
                      'services, including AI-powered item matching, '
                      'notifications about potential matches, and account '
                      'management. We do not sell your personal information to '
                      'third parties.',
                ),
                _PrivacySection(
                  heading: '3. AI and Data Processing',
                  body:
                      'Our AI matching system processes item descriptions and '
                      'images to find potential matches between lost and found '
                      'items. AI-generated confidence scores and predictions '
                      'are derived from this processing. Your data is processed '
                      'securely and is not shared with external AI services '
                      'beyond what is necessary for matching.',
                ),
                _PrivacySection(
                  heading: '4. Data Storage and Security',
                  body:
                      'Your data is stored securely using Firebase services '
                      'with industry-standard encryption. We implement '
                      'appropriate technical and organizational measures to '
                      'protect your personal information against unauthorized '
                      'access, alteration, disclosure, or destruction.',
                ),
                _PrivacySection(
                  heading: '5. Notifications',
                  body:
                      'We may send push notifications to alert you about '
                      'potential item matches, chat messages, and account '
                      'updates. You can manage your notification preferences '
                      'in the Settings screen at any time.',
                ),
                _PrivacySection(
                  heading: '6. Data Retention',
                  body:
                      'We retain your information for as long as your account '
                      'is active or as needed to provide our services. You can '
                      'request account deletion at any time, which will remove '
                      'your personal data from our systems.',
                ),
                _PrivacySection(
                  heading: '7. Third-Party Services',
                  body:
                      'We use Firebase for authentication, database, and '
                      'cloud storage. We may use additional third-party '
                      'services for analytics and push notifications. These '
                      'services have their own privacy policies governing use '
                      'of your data.',
                ),
                _PrivacySection(
                  heading: '8. Children\'s Privacy',
                  body:
                      'Our services are not intended for users under the age '
                      'of 13. We do not knowingly collect personal information '
                      'from children. If you believe a child has provided us '
                      'with personal information, please contact us immediately.',
                ),
                _PrivacySection(
                  heading: '9. Changes to This Policy',
                  body:
                      'We may update this Privacy Policy from time to time. '
                      'Material changes will be communicated through the app '
                      'or via email. Your continued use of the app after '
                      'changes constitutes acceptance of the updated policy.',
                ),
                _PrivacySection(
                  heading: '10. Contact Us',
                  body:
                      'If you have questions about this Privacy Policy, please '
                      'contact us at support@kahkenshaney.app.',
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & FAQ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Find answers to common questions about KAH KEN SHA NEY.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 24),
                _FaqTile(
                  question: 'How does the app work?',
                  answer:
                      'KAH KEN SHA NEY is an AI-powered lost and found platform. '
                      'If you\'ve lost an item, report it with a photo and description. '
                      'If you\'ve found an item, submit it to our database. Our AI '
                      'system will automatically scan and match lost items with found '
                      'items based on visual similarity and description keywords.',
                ),
                _FaqTile(
                  question: 'How do I report a lost item?',
                  answer:
                      'Go to the home screen and tap "Report Lost Item". Fill in the '
                      'details including a photo, description, location where you last '
                      'saw it, and the approximate date it was lost. Once submitted, '
                      'our AI will scan for potential matches and notify you if a match '
                      'is found.',
                ),
                _FaqTile(
                  question: 'How does AI matching work?',
                  answer:
                      'Our AI uses computer vision and natural language processing to '
                      'compare lost and found item reports. It analyzes item images for '
                      'visual similarities (color, shape, size, type) and cross-references '
                      'descriptions for keyword matches. Each match receives a confidence '
                      'score indicating how likely the items are the same.',
                ),
                _FaqTile(
                  question: 'How do I claim an item?',
                  answer:
                      'When you see a potential match, tap on it to view the details. '
                      'If you believe the item is yours, tap "Claim Item" and follow the '
                      'verification process. You may be asked to provide proof of '
                      'ownership or answer security questions to verify the item belongs '
                      'to you.',
                ),
                _FaqTile(
                  question: 'How do I contact support?',
                  answer:
                      'You can reach our support team by going to Settings > Support > '
                      'Contact Support, or by emailing us directly at '
                      'support@kahkenshaney.app. We typically respond within 24-48 hours.',
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 28,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Still need help?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Email us at support@kahkenshaney.app',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContactSupportScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Contact Support'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        iconColor: AppColors.primary,
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key, this.initialSubject});

  final String? initialSubject;

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String? _selectedSubject;

  static const List<String> _subjects = [
    'General Inquiry',
    'Bug Report',
    'Feature Request',
    'Account Issue',
    'Report a Problem',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null) {
      _selectedSubject = widget.initialSubject;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = _selectedSubject ?? 'General Inquiry';
    final message = _messageController.text.trim();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    try {
      await FirebaseFirestore.instance.collection('supportMessages').add({
        'subject': subject,
        'message': message,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (mounted) {
      _messageController.clear();
      setState(() => _selectedSubject = null);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text('Message Sent'),
            ],
          ),
          content: Text(
            'Thank you for reaching out! We have recorded your message and will '
            'get back to you at $email within 24-48 hours.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact Support',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How can we help?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill out the form below and we will get back to you as soon as possible.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Subject',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubject,
                        isExpanded: true,
                        hint: const Text(
                          'Select a subject',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                        items: _subjects
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSubject = v),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 6,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Describe your issue or question...',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your message';
                      }
                      if (v.trim().length < 10) {
                        return 'Message must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send Message'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Or email us directly at support@kahkenshaney.app',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
