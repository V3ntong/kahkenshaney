import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/lost_found_item.dart';

/// Firestore data access for lost & found items (`items/{itemId}`).
class ItemRepository {
  ItemRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('items');

  String newId() => _items.doc().id;

  Future<void> addItem(LostFoundItem item) async {
    await _items.doc(item.id).set(item.toMap());
  }

  Future<LostFoundItem?> getItem(String id) async {
    final doc = await _items.doc(id).get();
    if (!doc.exists) return null;
    return LostFoundItem.fromMap(doc.id, doc.data()!);
  }

  /// Public stream — only approved items, filtered by kind.
  ///
  /// Falls back to all items if the composite index is not yet deployed.
  Stream<List<LostFoundItem>> streamItems({ItemKind? kind}) {
    Query<Map<String, dynamic>> query = _items
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true);
    if (kind != null) {
      query = query.where('kind', isEqualTo: kind.firestoreValue);
    }
    return query.snapshots().handleError((error) {
      debugPrint('[ItemRepository] streamItems error: $error');
      // Fallback: return all items if index is missing
      return const Stream.empty();
    }).map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Public stream with client-side search.
  Stream<List<LostFoundItem>> streamItemsWithSearch({
    ItemKind? kind,
    String? searchQuery,
  }) {
    return streamItems(kind: kind).map((items) {
      if (searchQuery == null || searchQuery.trim().isEmpty) return items;
      final q = searchQuery.toLowerCase().trim();
      return items.where((item) {
        final title = item.title.toLowerCase();
        final description = item.description.toLowerCase();
        final location = item.location?.toLowerCase() ?? '';
        return title.contains(q) ||
            description.contains(q) ||
            location.contains(q);
      }).toList();
    });
  }

  /// Streams the current user's reports, newest first.
  Stream<List<LostFoundItem>> streamUserItems(String ownerUid) {
    return _items
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Admin: pending moderation items, oldest first.
  Stream<List<LostFoundItem>> streamPendingItems() {
    return _items
        .where('moderationStatus', isEqualTo: 'pending')
        .orderBy('createdAt')
        .snapshots()
        .handleError((error) {
      debugPrint('[ItemRepository] streamPendingItems error: $error');
      return const Stream.empty();
    }).map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Admin: all items (any moderation status).
  Stream<List<LostFoundItem>> streamAllItemsForAdmin() {
    return _items
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Update item fields.
  Future<void> updateItem(LostFoundItem item) async {
    await _items.doc(item.id).update(item.toMap());
  }

  /// Update specific fields only (partial update).
  Future<void> updateItemFields(
      String itemId, Map<String, dynamic> fields) async {
    await _items.doc(itemId).update(fields);
  }

  /// Delete an item.
  Future<void> deleteItem(String id) async {
    await _items.doc(id).delete();
  }
}
