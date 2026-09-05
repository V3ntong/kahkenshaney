import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Thrown when the server rejects a match confirmation; [message] is the
/// user-facing text returned by the Cloud Function.
class MatchApiException implements Exception {
  const MatchApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the `confirmMatch` Cloud Function.
///
/// Atomically links two opposite-kind items via `matchedItemId` and moves
/// both to the `matched` status. The server validates that the caller is an
/// admin or the reporter/owner of either item.
class MatchApi {
  MatchApi({FirebaseFunctions? functions}) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  static const String _region = 'us-central1';

  FirebaseFunctions _functions() {
    if (_functionsOverride != null) return _functionsOverride;
    if (Firebase.apps.isEmpty) {
      throw const MatchApiException(
        'Firebase is not configured on this platform.',
      );
    }
    return FirebaseFunctions.instanceFor(region: _region);
  }

  /// Confirms [itemId] and [matchedItemId] are the same object.
  Future<void> confirmMatch({
    required String itemId,
    required String matchedItemId,
  }) async {
    try {
      final callable = _functions().httpsCallable('confirmMatch');
      await callable.call<Map<String, dynamic>>({
        'itemId': itemId,
        'matchedItemId': matchedItemId,
      });
    } on MatchApiException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw MatchApiException(message);
      }
      throw MatchApiException(_fallback(e.code));
    } catch (e) {
      debugPrint('[MatchApi] confirmMatch unexpected error: $e');
      throw const MatchApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  String _fallback(String code) {
    final normalized = code.replaceFirst('functions/', '');
    switch (normalized) {
      case 'permission-denied':
        return 'Only the item reporters or an admin can confirm a match.';
      case 'failed-precondition':
        return 'This item is no longer open for matching.';
      case 'not-found':
        return 'One of the items no longer exists.';
      case 'unauthenticated':
        return 'You are not signed in.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}