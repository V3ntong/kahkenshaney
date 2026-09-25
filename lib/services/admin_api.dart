import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Client for the `grantAdminIfAuthorized` Cloud Function.
///
/// Admin assignment is a server-side decision: the function checks the
/// caller's verified email against the designated admin email and only then
/// sets `isAdmin: true` on the user document (via the Admin SDK, bypassing
/// client rules). The client never writes privileged fields itself.
class AdminApi {
  AdminApi({FirebaseFunctions? functions}) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  static const String _region = 'us-central1';

  FirebaseFunctions _functions() {
    if (_functionsOverride != null) return _functionsOverride;
    if (Firebase.apps.isEmpty) {
      debugPrint('[AdminApi] Firebase is not configured on this platform.');
      throw Exception('Firebase is not configured on this platform.');
    }
    return FirebaseFunctions.instanceFor(region: _region);
  }

  /// Asks the server to promote the signed-in caller to admin if their
  /// verified email matches the designated admin email.
  Future<bool> grantAdminIfAuthorized() async {
    try {
      final callable = _functions().httpsCallable('grantAdminIfAuthorized');
      final result =
          await callable.call<Map<String, dynamic>>(<String, dynamic>{});
      return result.data['granted'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[AdminApi] grantAdminIfAuthorized error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('[AdminApi] grantAdminIfAuthorized unexpected error: $e');
      return false;
    }
  }

  // ── Administrator invitations ──────────────────────────────────────────
  //
  // All of these are server-side only: the client never writes the
  // `adminInvites` collection or `isAdmin` fields itself (the old
  // `adminEmails` collection was denied by security rules anyway).

  /// Sends (or refreshes) an invitation to [email].
  Future<InviteResult> inviteAdmin(String email) =>
      _inviteCall('inviteAdmin', email);

  /// Re-sends an existing pending invitation to [email].
  Future<InviteResult> resendAdminInvite(String email) =>
      _inviteCall('resendAdminInvite', email);

  Future<InviteResult> _inviteCall(String name, String email) async {
    try {
      final callable = _functions().httpsCallable(name);
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'email': email.trim().toLowerCase()},
      );
      return InviteResult.fromMap(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[AdminApi] $name error: ${e.code} — ${e.message}');
      rethrow;
    }
  }

  /// Revokes the pending invitation for [email].
  Future<void> revokeAdminInvite(String email) =>
      _voidCall('revokeAdminInvite', <String, dynamic>{
        'email': email.trim().toLowerCase(),
      });

  /// The signed-in caller accepts their own invitation.
  Future<void> respondToAdminInvite() =>
      _voidCall('respondToAdminInvite', <String, dynamic>{});

  /// Revokes administrator access from the user document [uid].
  Future<void> removeAdminAccess(String uid) =>
      _voidCall('removeAdminAccess', <String, dynamic>{'uid': uid});

  Future<void> _voidCall(String name, Map<String, dynamic> payload) async {
    try {
      final callable = _functions().httpsCallable(name);
      await callable.call<Map<String, dynamic>>(payload);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[AdminApi] $name error: ${e.code} — ${e.message}');
      rethrow;
    }
  }

  /// Fetches the signed-in caller's pending invitation, or null.
  Future<PendingInvite?> getMyAdminInvite() async {
    try {
      final callable = _functions().httpsCallable('getMyAdminInvite');
      final result =
          await callable.call<Map<String, dynamic>>(<String, dynamic>{});
      final invite = result.data['invite'];
      if (invite is! Map) return null;
      return PendingInvite.fromMap(Map<String, dynamic>.from(invite));
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[AdminApi] getMyAdminInvite error: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('[AdminApi] getMyAdminInvite unexpected error: $e');
      return null;
    }
  }

  /// Turns a callable failure into a message that is safe to show the user.
  static String messageFor(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      switch (error.code) {
        case 'unauthenticated':
          return 'You must be signed in.';
        case 'permission-denied':
          return 'Only administrators can do that.';
        case 'not-found':
          return 'That invitation no longer exists.';
        case 'failed-precondition':
          return 'That action is not allowed right now.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait a moment.';
        case 'unavailable':
          return 'The service is temporarily unavailable. Please try again.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Result of sending/resending an invitation.
class InviteResult {
  const InviteResult({
    required this.inviteId,
    required this.resent,
    required this.emailSent,
  });

  final String inviteId;
  final bool resent;
  final bool emailSent;

  factory InviteResult.fromMap(Map<String, dynamic> map) => InviteResult(
        inviteId: map['inviteId'] as String? ?? '',
        resent: map['resent'] as bool? ?? false,
        emailSent: map['emailSent'] as bool? ?? false,
      );
}

/// A pending administrator invitation belonging to the signed-in user.
class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.email,
    required this.invitedByEmail,
    this.sentAt,
    this.expiresAt,
  });

  final String id;
  final String email;
  final String invitedByEmail;
  final DateTime? sentAt;
  final DateTime? expiresAt;

  factory PendingInvite.fromMap(Map<String, dynamic> map) => PendingInvite(
        id: map['id'] as String? ?? '',
        email: map['email'] as String? ?? '',
        invitedByEmail: map['invitedByEmail'] as String? ?? '',
        sentAt: _parseDate(map['sentAt']),
        expiresAt: _parseDate(map['expiresAt']),
      );

  static DateTime? _parseDate(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}