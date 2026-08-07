import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppAlertType { info, success, error }

class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.message,
    this.type = AppAlertType.info,
  });

  final String message;
  final AppAlertType type;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, IconData icon) = switch (type) {
      AppAlertType.info => (
          AppColors.infoSurface,
          AppColors.info,
          Icons.info_rounded,
        ),
      AppAlertType.success => (
          AppColors.successSurface,
          AppColors.success,
          Icons.check_circle_rounded,
        ),
      AppAlertType.error => (
          AppColors.errorSurface,
          AppColors.error,
          Icons.error_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
