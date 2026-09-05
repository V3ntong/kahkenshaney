import 'package:flutter/material.dart';

import '../screens/user_chat_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';

/// Messages tab — shows the user's support chat with admin.
///
/// If the user is not signed in, shows a placeholder.
/// If the user is the admin, shows a message to use the admin dashboard.
class MessagesPage extends StatelessWidget {
  const MessagesPage({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const FadeSlideInWidget(child: _NotSignedIn());
    }

    return FutureBuilder<String?>(
      future: lookupAdminUid(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final adminUid = snapshot.data;

        // If admin UID couldn't be resolved, show error
        if (adminUid == null) {
          return const FadeSlideInWidget(child: _AdminMissing());
        }

        // If the current user is the admin, redirect to admin dashboard.
        if (userId == adminUid) {
          return const FadeSlideInWidget(child: _AdminNotice());
        }

        return FadeSlideInWidget(
          duration: const Duration(milliseconds: 400),
          child: UserChatScreen(
            userId: userId!,
            adminUid: adminUid,
          ),
        );
      },
    );
  }
}

class _AdminMissing extends StatelessWidget {
  const _AdminMissing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.warningSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Admin not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Could not find an admin account. Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                size: 36,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign in to chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please sign in to access support chat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNotice extends StatelessWidget {
  const _AdminNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.infoSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 36,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Admin Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the Admin Dashboard to view and reply to user messages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
