import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/lost_found_item.dart';

/// Read-only Firestore access used by the Admin Dashboard.
///
/// Aggregates the same `items` and `users` collections the app already uses,
/// reusing the existing [LostFoundItem] model. Keeping this separate avoids
/// touching the user-facing repositories.
class AdminRepository {
  // ignore: prefer_initializing_formals
  AdminRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  /// Resolved lazily so subclasses in tests can override the stream methods
  /// without touching Firestore.
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Stream of all lost & found reports, newest first.
  Stream<List<LostFoundItem>> streamAllItems() {
    return _db
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Stream of the total number of registered users.
  Stream<int> streamUserCount() {
    return _db
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Stream of all user documents, ordered by creation time descending.
  Stream<List<Map<String, dynamic>>> streamUsers() {
    return _db.collection('users').snapshots().map(
          (snap) => snap.docs.map((doc) => {
                'uid': doc.id,
                ...doc.data(),
              }).toList(),
        );
  }

  /// Stream of total unread message count across all chats for the admin.
  Stream<int> streamAdminUnreadCount() {
    return _db.collection('chats').snapshots().map((snap) {
      var total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['unreadByAdminCount'] as num?)?.toInt() ?? 0;
      }
      return total;
    });
  }
}
