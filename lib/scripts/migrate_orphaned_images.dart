import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';

/// One-off migration script for orphaned images in the `lost_and_found/`
/// Storage folder that don't have matching Firestore documents.
///
/// Run with:
///   dart run lib/scripts/migrate_orphaned_images.dart
///
/// Each backfilled document gets placeholder metadata and a `needsReview: true`
/// flag so an admin can edit it later.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final storage = FirebaseStorage.instance;
  final firestore = FirebaseFirestore.instance;

  print('Scanning lost_and_found/ for orphaned images…');

  final allPaths = <(String url, String path)>[];
  await _scanFolder(storage.ref('lost_and_found'), allPaths);

  print('Found ${allPaths.length} images in Storage.');

  // Collect every storagePath already referenced in Firestore.
  final existingPaths = <String>{};
  final snap = await firestore.collection('items').get();
  for (final doc in snap.docs) {
    final data = doc.data();
    final sp = data['storagePath'] as String?;
    if (sp != null) existingPaths.add(sp);
    // Also index media list entries.
    final media = data['media'] as List?;
    if (media != null) {
      for (final m in media) {
        if (m is String) existingPaths.add(m);
      }
    }
  }

  print('Firestore already references ${existingPaths.length} paths.');

  var created = 0;
  for (final entry in allPaths) {
    final (url, path) = entry;
    if (existingPaths.contains(path)) continue;

    // Determine kind from path: lost_and_found/lost/… or lost_and_found/found/…
    final segments = path.split('/');
    final kind = segments.length >= 2 ? segments[1] : 'unknown';

    await firestore.collection('items').add({
      'kind': kind == 'found' ? 'found' : 'lost',
      'title': 'Untitled',
      'description': '',
      'ownerUid': '',
      'location': 'Unknown',
      'status': 'open',
      'media': [url],
      'imageUrl': url,
      'storagePath': path,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'needsReview': true,
    });

    created++;
    print('  Created doc for $path');
  }

  print('Migration complete. Created $created document(s).');
}

Future<void> _scanFolder(
  Reference ref,
  List<(String url, String path)> results,
) async {
  final list = await ref.listAll();
  for (final item in list.items) {
    try {
      final url = await item.getDownloadURL();
      results.add((url, item.fullPath));
    } catch (e) {
      print('  Skipping ${item.fullPath}: $e');
    }
  }
  for (final prefix in list.prefixes) {
    await _scanFolder(prefix, results);
  }
}
