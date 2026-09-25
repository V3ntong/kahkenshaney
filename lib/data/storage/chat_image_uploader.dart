import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Upload failure with a message that is safe to show directly to the user.
///
/// Thrown for both pre-flight validation failures (wrong type / too large)
/// and mapped Storage errors, so callers never have to translate raw
/// `FirebaseException` codes themselves. [preflight] distinguishes failures
/// caught before any network call (show a transient snackbar) from real
/// upload failures (which deserve an on-screen retry affordance).
class ChatImageUploadException implements Exception {
  const ChatImageUploadException(this.message, {this.preflight = false});

  final String message;
  final bool preflight;

  @override
  String toString() => message;
}

/// Validates and uploads chat attachments to `chat_images/{fileName}`.
///
/// Shared by the user support chat and the admin chat detail screen so both
/// enforce the same rules:
///  - pre-flight checks (size + MIME type) fail fast with a specific message
///    instead of a network round-trip that a generic snackbar hides;
///  - the upload always declares an explicit `contentType` so the Storage
///    rule `request.resource.contentType.matches('image/.*')` can never fail
///    because the platform inferred `application/octet-stream`;
///  - the uploader UID is recorded in `metadataUploaderId` custom metadata,
///    which is what the Storage delete rule matches against;
///  - an App Check token is force-refreshed first, so clients behind App
///    Check enforcement don't fail with an expired/absent token.
class ChatImageUploader {
  const ChatImageUploader._();

  /// Maximum attachment size accepted by both client and Storage rules.
  static const int maxBytes = 10 * 1024 * 1024;

  static const Set<String> allowedExtensions = {
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif',
  };

  static const String _storageFolder = 'chat_images';

  /// Validates [file] and uploads it, returning the download URL.
  ///
  /// Throws [ChatImageUploadException] with a user-facing message on any
  /// failure.
  static Future<String> upload({
    required File file,
    required String uploaderUid,
    required String fileName,
  }) async {
    await _validate(file);
    await _refreshAppCheckToken();

    final ref = FirebaseStorage.instance.ref('$_storageFolder/$fileName');
    try {
      await ref.putFile(
        file,
        SettableMetadata(
          contentType: _contentTypeFor(file.path),
          customMetadata: {'metadataUploaderId': uploaderUid},
        ),
      );
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('[ChatImageUploader] upload failed: ${e.code} — ${e.message}');
      throw ChatImageUploadException(messageFor(e));
    } catch (e) {
      debugPrint('[ChatImageUploader] unexpected upload error: $e');
      throw const ChatImageUploadException(
        'Upload failed. Please check your connection and try again.',
      );
    }
  }

  /// Pre-flight validation — cheap checks that catch avoidable failures
  /// before any network call happens.
  static Future<void> _validate(File file) async {
    if (!await file.exists()) {
      throw const ChatImageUploadException(
        'That file could not be found.',
        preflight: true,
      );
    }

    final extension = _extensionOf(file.path);
    if (!allowedExtensions.contains(extension)) {
      throw const ChatImageUploadException(
        'Only image files can be sent (JPG, PNG, WEBP, HEIC).',
        preflight: true,
      );
    }

    final size = await file.length();
    if (size > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      throw ChatImageUploadException(
        'Images must be smaller than $mb MB.',
        preflight: true,
      );
    }
    if (size == 0) {
      throw const ChatImageUploadException(
        'That image appears to be empty.',
        preflight: true,
      );
    }
  }

  /// Best-effort App Check token refresh. No-op when App Check is not
  /// configured for this build; required when Storage enforces App Check.
  static Future<void> _refreshAppCheckToken() async {
    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (e) {
      debugPrint('[ChatImageUploader] App Check token refresh skipped: $e');
    }
  }

  /// Translates a Storage [error] into a user-facing message.
  static String messageFor(FirebaseException error) {
    switch (error.code) {
      case 'storage/app-check-unauthorized':
      case 'storage/app-check-unverified':
        return 'Your device could not be verified. Please try again in a moment.';
      case 'storage/unauthorized':
        return "You don't have permission to upload images. Please sign in again.";
      case 'storage/retry-limit-exceeded':
        return 'Network error while uploading. Check your connection and retry.';
      case 'storage/canceled':
        return 'Upload was canceled.';
      case 'storage/quota-exceeded':
        return 'Storage space is exhausted. Please contact support.';
      case 'storage/bucket-not-found':
      case 'storage/project-not-located':
        return 'Upload service is misconfigured. Please contact support.';
      case 'storage/unknown':
        return 'Upload failed unexpectedly. Please try again.';
      default:
        return 'Failed to upload image. Please try again.';
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeFor(String path) {
    switch (_extensionOf(path)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}
