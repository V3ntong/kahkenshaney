import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore data service for the Lost & Found app.
///
/// Provides CRUD operations for items and user profiles.
/// Uses injectable [FirebaseFirestore] for testability.
class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Items ──────────────────────────────────────────────────────────────

  /// Save a lost/found report to the `items` collection.
  ///
  /// Returns the generated document ID on success.
  /// Throws [DatabaseException] on failure.
  Future<String> reportItem({
    required String itemName,
    required String description,
    required String userId,
    required String status, // 'lost' or 'found'
    String? imageUrl,
    String? location,
  }) async {
    try {
      final docRef = await _db.collection('items').add({
        'itemName': itemName,
        'description': description,
        'userId': userId,
        'status': status,
        'imageUrl': imageUrl ?? 'assets/images/placeholder_item.png',
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] Firestore error: ${e.code} — ${e.message}');
      throw DatabaseException(
        'Failed to save report. Please try again.',
        code: e.code,
      );
    } catch (e) {
      debugPrint('[DatabaseService] Unexpected error: $e');
      throw DatabaseException('An unexpected error occurred.');
    }
  }

  /// Stream of items, optionally filtered by status.
  Stream<List<Map<String, dynamic>>> streamItems({String? status}) {
    Query<Map<String, dynamic>> query = _db
        .collection('items')
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map(
          (snap) => snap.docs.map((doc) => {
                'id': doc.id,
                ...doc.data(),
              }).toList(),
        );
  }

  /// Get a single item by ID.
  Future<Map<String, dynamic>?> getItem(String itemId) async {
    try {
      final doc = await _db.collection('items').doc(itemId).get();
      if (!doc.exists || doc.data() == null) return null;
      return {'id': doc.id, ...doc.data()!};
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] getItem error: ${e.code}');
      throw DatabaseException('Failed to load item.');
    }
  }

  /// Update an existing item document.
  Future<void> updateItem(String itemId, Map<String, dynamic> data) async {
    try {
      await _db.collection('items').doc(itemId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] updateItem error: ${e.code}');
      throw DatabaseException('Failed to update item.');
    }
  }

  /// Delete an item by ID.
  Future<void> deleteItem(String itemId) async {
    try {
      await _db.collection('items').doc(itemId).delete();
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] deleteItem error: ${e.code}');
      throw DatabaseException('Failed to delete item.');
    }
  }

  // ── User Profiles ──────────────────────────────────────────────────────

  /// Create or overwrite a user profile in the `users` collection.
  ///
  /// Uses [SetOptions(merge: true)] so existing fields are not overwritten.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? displayName,
    String role = 'user',
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'email': email,
        'displayName': displayName ?? '',
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] createUserProfile error: ${e.code}');
      throw DatabaseException('Failed to create profile.');
    }
  }

  /// Get a user profile by UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return {'uid': doc.id, ...doc.data()!};
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] getUserProfile error: ${e.code}');
      throw DatabaseException('Failed to load profile.');
    }
  }

  /// Update specific fields of a user profile.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('[DatabaseService] updateUserProfile error: ${e.code}');
      throw DatabaseException('Failed to update profile.');
    }
  }
}

/// Custom exception for database operations with user-friendly messages.
class DatabaseException implements Exception {
  const DatabaseException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'DatabaseException($code): $message';
}
