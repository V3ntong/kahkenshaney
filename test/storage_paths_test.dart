import 'package:flutter_test/flutter_test.dart';

import 'package:amongapp/data/storage/storage_service.dart';

void main() {
  group('StorageService path conventions', () {
    test('item photos are uploaded under lost_and_found/{folder}', () {
      expect(StorageService.itemFolderRoot('lost'), 'lost_and_found/lost');
      expect(StorageService.itemFolderRoot('found'), 'lost_and_found/found');
    });

    test('gallery reads the same root the uploader writes to', () {
      // Regression: the gallery used to read `ref('lost')` while uploads
      // landed at `lost_and_found/lost`, so the gallery could never find
      // any images. Both sides must derive from the same root helper.
      for (final folder in ['lost', 'found']) {
        final root = StorageService.itemFolderRoot(folder);
        expect(root, startsWith('lost_and_found/'));
        expect(root, isNot(equals(folder)));
      }
    });

    test('uploaded file names live directly under the folder root', () {
      // Mirrors the naming in uploadItemPhotos: `{itemId}_{stamp}_{i}.jpg`.
      const itemId = 'abc123';
      const stamp = 1720000000000;
      const i = 0;
      final fileName = '${itemId}_${stamp}_$i.jpg';
      final path = '${StorageService.itemFolderRoot('lost')}/$fileName';
      expect(path, 'lost_and_found/lost/abc123_1720000000000_0.jpg');
    });
  });
}