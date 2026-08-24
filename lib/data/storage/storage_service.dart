import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Result of a single file upload containing both the download URL and
/// the Storage path so the caller can persist both in Firestore.
class UploadResult {
  const UploadResult({required this.url, required this.path});
  final String url;
  final String path;
}

/// Firebase Storage helpers for item photos.
///
/// Uploads are routed to `lost_and_found/{type}/{fileName}.jpg` per the
/// data-integrity requirement. Each upload returns an [UploadResult] so the
/// caller can store both the download URL and the Storage path together.
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads the given photos and returns their download URLs + Storage paths.
  ///
  /// Images are stored under `lost_and_found/{type}/{fileName}.jpg` where
  /// `{fileName}` is a timestamp-based unique name to avoid collisions.
  Future<List<UploadResult>> uploadItemPhotos({
    required String folder,
    required String itemId,
    required List<File> images,
  }) async {
    final results = <UploadResult>[];
    for (var i = 0; i < images.length; i++) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${itemId}_${stamp}_$i.jpg';
      final path = 'lost_and_found/$folder/$fileName';
      final ref = _storage.ref(path);
      await ref.putFile(images[i]);
      final url = await ref.getDownloadURL();
      results.add(UploadResult(url: url, path: path));
    }
    return results;
  }

  /// Legacy upload that returns only download URLs (backward-compatible).
  Future<List<String>> uploadItemPhotosUrls({
    required String folder,
    required String itemId,
    required List<File> images,
  }) async {
    final results = await uploadItemPhotos(
      folder: folder,
      itemId: itemId,
      images: images,
    );
    return results.map((r) => r.url).toList();
  }

  /// Fetches the download URLs of every image under [folderName]
  /// (`lost` or `found`). Traverses any nested subfolders (e.g. item-id
  /// folders) so both flat and grouped layouts are supported.
  Future<List<String>> fetchImagesFromFolder(String folderName) async {
    final urls = <String>[];
    await _collectImages(_storage.ref(folderName), urls);
    return urls;
  }

  Future<void> _collectImages(Reference ref, List<String> urls) async {
    final result = await ref.listAll();
    for (final item in result.items) {
      try {
        urls.add(await item.getDownloadURL());
      } catch (e) {
        debugPrint(
            'StorageService: failed to get URL for ${item.fullPath}: $e');
      }
    }
    for (final prefix in result.prefixes) {
      await _collectImages(prefix, urls);
    }
  }

  /// Lists all files under the `lost_and_found` root and resolves download
  /// URLs. Returns a list of [UploadResult] entries for items that exist in
  /// Storage but may lack a corresponding Firestore document.
  Future<List<UploadResult>> listOrphanedImages() async {
    final results = <UploadResult>[];
    await _collectOrphaned(_storage.ref('lost_and_found'), results);
    return results;
  }

  Future<void> _collectOrphaned(
    Reference ref,
    List<UploadResult> results,
  ) async {
    final listResult = await ref.listAll();
    for (final item in listResult.items) {
      try {
        final url = await item.getDownloadURL();
        results.add(UploadResult(url: url, path: item.fullPath));
      } catch (e) {
        debugPrint(
            'StorageService: failed to resolve orphaned image ${item.fullPath}: $e');
      }
    }
    for (final prefix in listResult.prefixes) {
      await _collectOrphaned(prefix, results);
    }
  }
}
