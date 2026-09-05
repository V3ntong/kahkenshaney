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
}