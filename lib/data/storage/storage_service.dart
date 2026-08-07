import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage uploads for item photos (`items/{itemId}/...`).
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads the given photos and returns their download URLs.
  Future<List<String>> uploadItemPhotos({
    required String itemId,
    required List<File> images,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('items/$itemId/${stamp}_$i.jpg');
      await ref.putFile(images[i]);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }
}
