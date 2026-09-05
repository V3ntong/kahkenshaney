import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Thrown when the server rejects a claim; [message] is the user-facing text
/// returned by the Cloud Function (e.g. the self-claim rejection message).
class ClaimApiException implements Exception {
  const ClaimApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the `claimItem` Cloud Function.
///
/// The server performs the authoritative validation (a user cannot claim an
/// item they reported themselves, terminal/already-claimed items are
/// rejected); this client only surfaces the result.
class ClaimApi {
  ClaimApi({FirebaseFunctions? functions}) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  static const String _region = 'us-central1';

  FirebaseFunctions _functions() {
    if (_functionsOverride != null) return _functionsOverride;
    if (Firebase.apps.isEmpty) {
      throw const ClaimApiException(
        'Firebase is not configured on this platform.',
      );
    }
    return FirebaseFunctions.instanceFor(region: _region);
  }

  /// Submits a claim for [itemId]. Throws [ClaimApiException] with the
  /// server's message when the claim is rejected.
  Future<void> claimItem(String itemId) async {
    try {
      final callable = _functions().httpsCallable('claimItem');
      await callable.call<Map<String, dynamic>>({'itemId': itemId});
    } on ClaimApiException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw ClaimApiException(message);
      }
      throw ClaimApiException(_fallback(e.code));
    } catch (e) {
      debugPrint('[ClaimApi] claimItem unexpected error: $e');
      throw const ClaimApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  String _fallback(String code) {
    final normalized = code.replaceFirst('functions/', '');
    switch (normalized) {
      case 'permission-denied':
        return 'You cannot claim an item you reported yourself.';
      case 'already-exists':
        return 'This item has already been claimed.';
      case 'failed-precondition':
        return 'This item is no longer open for claims.';
      case 'not-found':
        return 'This item no longer exists.';
      case 'unauthenticated':
        return 'You are not signed in.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}