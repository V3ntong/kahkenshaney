import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Prompt shown on Home when the signed-in user has a pending administrator
/// invitation.
///
/// Accepting calls the `respondToAdminInvite` Cloud Function, which grants
/// `isAdmin` based on the caller's *authenticated* email — the client never
/// writes privileged fields itself. Shown only when an invitation exists,
/// otherwise renders nothing.
class AdminInviteBanner extends StatefulWidget {
  const AdminInviteBanner({super.key, this.onAccepted});

  /// Called after a successful acceptance (e.g. to refresh admin state).
  final VoidCallback? onAccepted;

  @override
  State<AdminInviteBanner> createState() => _AdminInviteBannerState();
}

class _AdminInviteBannerState extends State<AdminInviteBanner> {
  final _api = AdminApi();

  PendingInvite? _invite;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Yield first so any failure path calls setState outside of initState.
    await Future<void>.delayed(Duration.zero);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final invite = await _api.getMyAdminInvite();
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _loading = false;
      });
    } catch (e) {
      // Never let a missing/unconfigured Firebase app break the Home feed
      // (widget tests and cold starts without Firebase are silent no-ops).
      debugPrint('[AdminInviteBanner] load failed: $e');
      if (mounted) {
        setState(() {
          _invite = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _accept() async {
    if (_busy || _invite == null) return;
    setState(() => _busy = true);
    try {
      await _api.respondToAdminInvite();
      // Refresh the cached admin check so the dashboard is reachable right
      // away instead of only after an app restart.
      try {
        await FirebaseAuthService().refreshAdminStatus();
      } catch (e) {
        debugPrint('[AdminInviteBanner] refreshAdminStatus failed: $e');
      }
      if (!mounted) return;
      setState(() => _invite = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You now have administrator access.')),
      );
      widget.onAccepted?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AdminApi.messageFor(e))));
      // The invite may have expired or been revoked — refresh the banner.
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _dismiss() {
    setState(() => _invite = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _invite == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator invitation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You have been invited to help manage KAH KEN SHA NEY. '
                        'Accept to get access to the admin dashboard.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _invite!.invitedByEmail.isEmpty
                        ? 'Sent to ${_invite!.email}'
                        : 'Invited by ${_invite!.invitedByEmail}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Not now'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _busy ? null : _accept,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
