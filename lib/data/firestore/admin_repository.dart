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

  /// Stream of admin emails from the adminEmails collection.
  Stream<List<Map<String, dynamic>>> streamAdminEmails() {
    return _db.collection('adminEmails').snapshots().map(
          (snap) => snap.docs.map((doc) => {
                'id': doc.id,
                ...doc.data(),
              }).toList(),
        );
  }

  /// Adds an admin email to the adminEmails collection.
  Future<void> addAdminEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    await _db.collection('adminEmails').add({
      'email': normalized,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes an admin email from the adminEmails collection.
  Future<void> removeAdminEmail(String docId) async {
    await _db.collection('adminEmails').doc(docId).delete();
  }

  /// Checks if an email is in the adminEmails collection.
  Future<bool> isEmailAdmin(String email) async {
    final normalized = email.trim().toLowerCase();
    final snapshot = await _db
        .collection('adminEmails')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
