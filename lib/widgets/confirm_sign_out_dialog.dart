import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// C1: polished logout confirmation shared by the user feed and the admin
/// dashboard.
///
/// Redesign of the original plain dialog: rounded corners matching the app's
/// design language, a logout icon in a tinted circle, clearer spacing, and a
/// button hierarchy where the destructive action is styled distinctly from
/// Cancel. Returns `true` when the user confirms.
Future<bool?> showConfirmSignOutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppColors.errorSurface,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.logout_rounded,
          size: 28,
          color: AppColors.error,
        ),
      ),
      title: const Text(
        'Log out',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: const Text(
        'Are you sure you want to log out of KAH KEN SHA NEY?',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      actions: [
        SizedBox(
          width: 120,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ),
      ],
    ),
  );
}
