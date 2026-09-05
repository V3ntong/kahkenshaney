import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Thrown when the server rejects a resolution; [message] is the
/// user-facing text returned by the Cloud Function.
class ResolveApiException implements Exception {
  const ResolveApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the `resolveItem` Cloud Function.
///
/// The server validates that the caller is an admin, and writes the terminal
/// `resolved` status + `resolvedAt`/`resolvedBy`
/// + status history atomically (direct client writes to `status` are blocked
/// by Firestore rules).
class ResolveApi {
  ResolveApi({FirebaseFunctions? functions}) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  static const String _region = 'us-central1';

  FirebaseFunctions _functions() {
    if (_functionsOverride != null) return _functionsOverride;
    if (Firebase.apps.isEmpty) {
      throw const ResolveApiException(
        'Firebase is not configured on this platform.',
      );
    }
    return FirebaseFunctions.instanceFor(region: _region);
  }

  /// Marks [itemId] as resolved. Throws [ResolveApiException] with the
  /// server's message when the resolution is rejected.
  Future<void> resolveItem(String itemId) async {
    try {
      final callable = _functions().httpsCallable('resolveItem');
      await callable.call<Map<String, dynamic>>({'itemId': itemId});
    } on ResolveApiException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw ResolveApiException(message);
      }
      throw ResolveApiException(_fallback(e.code));
    } catch (e) {
      debugPrint('[ResolveApi] resolveItem unexpected error: $e');
      throw const ResolveApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  String _fallback(String code) {
    final normalized = code.replaceFirst('functions/', '');
    switch (normalized) {
      case 'permission-denied':
        return 'Only an administrator can resolve an item.';
      case 'failed-precondition':
        return 'This item is already resolved.';
      case 'not-found':
        return 'This item no longer exists.';
      case 'unauthenticated':
        return 'You are not signed in.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
