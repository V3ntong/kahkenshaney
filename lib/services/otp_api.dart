import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;

class OtpApiException implements Exception {
  const OtpApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class OtpApi {
  Future<void> sendSignupOtp(String email);

  Future<void> verifySignupOtp({
    required String email,
    required String otp,
  });

  Future<void> sendPasswordResetOtp(String email);

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  });

  Future<void> sendChangePasswordOtp(String email);

  Future<void> verifyChangePasswordOtp({
    required String email,
    required String otp,
  });

  Future<void> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });
}

class FirebaseOtpApi implements OtpApi {
  FirebaseOtpApi({FirebaseFunctions? functions, bool? useEmulator})
      : _functionsOverride = functions {
    if (useEmulator != null) _useEmulator = useEmulator;
  }

  final FirebaseFunctions? _functionsOverride;

  bool _useEmulator = const bool.fromEnvironment('USE_FUNCTIONS_EMULATOR');

  bool get _platformSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static const String _region = 'us-central1';

  FirebaseFunctions _functions() {
    if (_functionsOverride != null) return _functionsOverride;
    if (Firebase.apps.isEmpty) {
      throw const OtpApiException(
        'Firebase is not configured on this platform. Run `flutterfire '
        'configure` to connect Firebase before using password recovery.',
      );
    }
    final functions = FirebaseFunctions.instance;
    if (_useEmulator) {
      functions.useFunctionsEmulator('localhost', 5001);
    }
    return functions;
  }

  @override
  Future<void> sendSignupOtp(String email) async {
    await _call('sendSignupOtp', {'email': email});
  }

  @override
  Future<void> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    await _call('verifySignupOtp', {'email': email, 'otp': otp});
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    await _call('sendPasswordResetOtp', {'email': email});
  }

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    await _call('verifyPasswordResetOtp', {'email': email, 'otp': otp});
  }

  @override
  Future<void> sendChangePasswordOtp(String email) async {
    await _call('sendChangePasswordOtp', {'email': email});
  }

  @override
  Future<void> verifyChangePasswordOtp({
    required String email,
    required String otp,
  }) async {
    await _call('verifyChangePasswordOtp', {'email': email, 'otp': otp});
  }

  @override
  Future<void> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _call('changePassword', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _call('resetPassword', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      if (_platformSupported) {
        await _callViaFunctions(name, data);
      } else {
        await _callViaRest(name, data);
      }
    } on OtpApiException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw OtpApiException(message);
      }
      throw OtpApiException(_fallback(e.code));
    } on MissingPluginException catch (e) {
      debugPrint('[otp_api] $name missing plugin: $e');
      throw const OtpApiException(
        'The backend plugin is not available on this platform.',
      );
    } on PlatformException catch (e) {
      debugPrint('[otp_api] $name platform error: $e');
      throw OtpApiException(
        e.message ?? 'Something went wrong. Please try again.',
      );
    } catch (e, s) {
      debugPrint('[otp_api] $name unexpected error: $e\n$s');
      throw const OtpApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  Future<void> _callViaFunctions(String name, Map<String, dynamic> data) async {
    final callable = _functions().httpsCallable(name);
    await callable.call<Map<String, dynamic>>(data);
  }

  Future<void> _callViaRest(String name, Map<String, dynamic> data) async {
    if (Firebase.apps.isEmpty) {
      throw const OtpApiException(
        'Firebase is not configured on this platform. Run `flutterfire '
        'configure` to connect Firebase before using password recovery.',
      );
    }
    final projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) {
      throw const OtpApiException(
        'Firebase is not configured on this platform. Run `flutterfire '
        'configure` to connect Firebase before using password recovery.',
      );
    }

    final origin = _useEmulator
        ? 'http://localhost:5001/$projectId/$_region'
        : 'https://$_region-$projectId.cloudfunctions.net';

    final headers = <String, String>{'Content-Type': 'application/json'};

    // Safely obtain the ID token for authenticated requests.
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final token = await user.getIdToken();
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
        } catch (e) {
          debugPrint('[otp_api] Failed to get ID token: $e');
        }
      }
    }

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$origin/$name'),
        headers: headers,
        body: jsonEncode({'data': data}),
      );
    } catch (e, s) {
      debugPrint('[otp_api] $name REST request failed: $e\n$s');
      throw const OtpApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) decoded = body;
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode == 200 && decoded?['result'] != null) {
      return;
    }

    final error = decoded?['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        throw OtpApiException(message);
      }
      final status = error['status'];
      if (status is String && status.isNotEmpty) {
        throw OtpApiException(_fallbackFromStatus(status));
      }
    }

    debugPrint(
      '[otp_api] $name REST error: HTTP ${response.statusCode} body=${response.body}',
    );
    throw OtpApiException(
      'Could not reach the server (HTTP ${response.statusCode}). '
      'Check your connection and try again.',
    );
  }

  String _fallback(String code) {
    final normalized = code.replaceFirst('functions/', '');
    switch (normalized) {
      case 'not-found':
        return 'No account found with this email address.';
      case 'resource-exhausted':
        return 'Too many attempts. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'unauthenticated':
        return 'You are not signed in.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _fallbackFromStatus(String status) {
    switch (status) {
      case 'NOT_FOUND':
        return 'No account found with this email address.';
      case 'INVALID_ARGUMENT':
        return 'Please check the information you entered.';
      case 'RESOURCE_EXHAUSTED':
        return 'Too many attempts. Please try again later.';
      case 'UNAVAILABLE':
        return 'Service temporarily unavailable. Please try again.';
      case 'UNAUTHENTICATED':
        return 'You are not signed in.';
      case 'PERMISSION_DENIED':
        return 'You can only change the password for your own account.';
      case 'DEADLINE_EXCEEDED':
        return 'This code has expired. Please request a new one.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
