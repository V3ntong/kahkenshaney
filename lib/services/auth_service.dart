import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'otp_api.dart';

/// The email address granted access to the Admin Dashboard.
///
/// Replace with the real admin email. This is the single source of truth
/// used both by the post-login redirect and the admin dashboard guard.
const String kAdminEmail = 'mugiwaranomelvin@gmail.com';

/// Cached admin UID fetched from Firestore.
String? _cachedAdminUid;

/// Looks up the admin UID from Firestore by querying the `users` collection
/// for the document where `isAdmin == true`.
///
/// Returns the UID of the first admin found, or null if no admin is found.
/// Caches the result for subsequent calls.
Future<String?> lookupAdminUid() async {
  if (_cachedAdminUid != null) return _cachedAdminUid;

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isAdmin', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      _cachedAdminUid = snapshot.docs.first.id;
      debugPrint('[AuthService] Admin UID resolved: $_cachedAdminUid');
      return _cachedAdminUid;
    }
  } catch (e) {
    debugPrint('[AuthService] lookupAdminUid error: $e');
  }
  return null;
}

/// Whether [email] matches the designated admin email (case-insensitive).
/// Also checks the adminEmails Firestore collection for dynamically added admins.
Future<bool> isAdminEmailAsync(String? email) async {
  if (email == null) return false;
  final trimmed = email.trim().toLowerCase();
  if (trimmed == kAdminEmail.trim().toLowerCase()) return true;

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('adminEmails')
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  } catch (e) {
    debugPrint('[AuthService] isAdminEmailAsync error: $e');
    return false;
  }
}

/// Whether [email] matches the designated admin email (case-insensitive).
/// This is the synchronous version; for full admin list check use isAdminEmailAsync.
bool isAdminEmail(String? email) {
  if (email == null) return false;
  return email.trim().toLowerCase() == kAdminEmail.trim().toLowerCase();
}

/// Cached result of async admin check.
bool _asyncAdminCheckResult = false;

/// Outcome of a login / registration attempt.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess({this.user});
  final User? user;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.message);
  final String message;
}

/// Thrown by OTP / password-recovery methods with a user-friendly message.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Contract for all auth operations used by the screens.
abstract class AuthService {
  /// The currently signed-in Firebase user, or null when not signed in.
  User? get currentUser;

  /// Whether a user is currently signed in.
  bool get isAuthenticated => currentUser != null;

  /// Whether the currently signed-in user is the designated admin email.
  /// Checks both the hardcoded admin email and the adminEmails Firestore collection.
  bool get isAdminAuthenticated => isAdminEmail(currentUser?.email) || _asyncAdminCheckResult;

  /// Checks and caches the admin status from Firestore for the current user.
  Future<void> refreshAdminStatus() async {
    _asyncAdminCheckResult = await isAdminEmailAsync(currentUser?.email);
  }

  /// Signs the current user out (no-op when no one is signed in).
  Future<void> signOut();

  Future<AuthResult> login({required String email, required String password});

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  });

  /// Resends the signup OTP to the given email.
  Future<void> resendSignupOtp(String email);

  /// Verifies the signup OTP for the given email and marks it verified.
  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  });

  Future<void> sendPasswordResetOtp(String email);

  /// Sends a change-password OTP to the given email.
  Future<void> sendChangePasswordOtp(String email);

  /// Verifies the change-password OTP for the given email.
  Future<void> verifyChangePasswordOtp({
    required String email,
    required String otp,
  });

  /// Applies a new password after the change-password OTP was verified.
  Future<void> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  });

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, OtpApi? otpApi})
      : _authOverride = auth,
        _otp = otpApi ?? FirebaseOtpApi();

  /// Allows tests to inject a mock instance.
  final FirebaseAuth? _authOverride;
  final OtpApi _otp;

  /// Resolved lazily so the constructor never throws, even when Firebase has
  /// not been initialized on the current platform.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _firebaseReady => _authOverride != null || Firebase.apps.isNotEmpty;

  static const String _notConfigured =
      'Firebase is not configured on this platform yet.';

  @override
  User? get currentUser {
    if (!_firebaseReady) return null;
    return _auth.currentUser;
  }

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  bool get isAdminAuthenticated => isAdminEmail(currentUser?.email) || _asyncAdminCheckResult;

  @override
  Future<void> refreshAdminStatus() async {
    _asyncAdminCheckResult = await isAdminEmailAsync(currentUser?.email);
  }

  @override
  Future<void> signOut() async {
    if (_firebaseReady) {
      await _auth.signOut();
    }
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (!_firebaseReady) {
      return const AuthFailure(_notConfigured);
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthSuccess();
    } on FirebaseAuthException catch (e) {
      return AuthFailure(_authErrorToMessage(e));
    } catch (_) {
      return const AuthFailure('Something went wrong. Please try again.');
    }
  }

  @override
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (!_firebaseReady) {
      return const AuthFailure(_notConfigured);
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(fullName.trim());
      }
      return AuthSuccess(user: user);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(_authErrorToMessage(e));
    } catch (e) {
      print('[AuthService] register unexpected error: $e');
      return const AuthFailure(
        'Something went wrong during registration. Please try again.',
      );
    }
  }

  @override
  Future<void> resendSignupOtp(String email) async {
    try {
      await _otp.sendSignupOtp(email);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _otp.verifySignupOtp(email: email, otp: otp);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _otp.sendPasswordResetOtp(email);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _otp.verifyPasswordResetOtp(email: email, otp: otp);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> sendChangePasswordOtp(String email) async {
    try {
      await _otp.sendChangePasswordOtp(email);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> verifyChangePasswordOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _otp.verifyChangePasswordOtp(email: email, otp: otp);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _otp.changePassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _otp.resetPassword(email: email, otp: otp, newPassword: newPassword);
    } on OtpApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  String _authErrorToMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
