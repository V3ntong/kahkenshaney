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

  /// Live stream of a single item document — status changes, claims and
  /// match scores update in real time without a page refresh.
  Stream<LostFoundItem?> streamItem(String id) {
    return _items.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LostFoundItem.fromMap(doc.id, doc.data()!);
    }).handleError((error) {
      debugPrint('[ItemRepository] streamItem error: $error');
      return const Stream.empty();
    });
  }

  /// Public stream — only approved items, filtered by kind.
  ///
  /// Excludes resolved items so they no longer appear on the Lost/Found
  /// listing pages. Falls back to all items if the composite index is
  /// not yet deployed.
  Stream<List<LostFoundItem>> streamItems({ItemKind? kind, int? limit}) {
    Query<Map<String, dynamic>> query = _items
        .where('moderationStatus', isEqualTo: 'approved')
        .where('status', isNotEqualTo: 'resolved')
        .orderBy('createdAt', descending: true);
    if (kind != null) {
      query = query.where('kind', isEqualTo: kind.firestoreValue);
    }
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList(),
    ).handleError((error) {
      debugPrint('[ItemRepository] streamItems error: $error');
      // Emit an empty list instead of Stream.empty() so the StreamBuilder
      // resolves to the loaded state rather than staying in waiting forever.
      return <LostFoundItem>[];
    });
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
    }).handleError((error) {
      debugPrint('[ItemRepository] streamUserItems error: $error');
      return <LostFoundItem>[];
    });
  }

  /// Admin: pending moderation items, oldest first.
  Stream<List<LostFoundItem>> streamPendingItems() {
    return _items
        .where('moderationStatus', isEqualTo: 'pending')
        .orderBy('createdAt')
        .snapshots()
        .map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList(),
    ).handleError((error) {
      debugPrint('[ItemRepository] streamPendingItems error: $error');
      return <LostFoundItem>[];
    });
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
    ).handleError((error) {
      debugPrint('[ItemRepository] streamAllItemsForAdmin error: $error');
      return <LostFoundItem>[];
    });
  }

  /// Admin: approved items that are NOT yet resolved/claimed/closed.
  Stream<List<LostFoundItem>> streamNonTerminalItems() {
    return _items
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .where((item) => !item.status.isTerminal)
          .toList(),
    ).handleError((error) {
      debugPrint('[ItemRepository] streamNonTerminalItems error: $error');
      return <LostFoundItem>[];
    });
  }

  /// Resolved items stream — for the Reports page "Recently Resolved Items".
  ///
  /// Returns approved items with `status == 'resolved'`, sorted by
  /// `resolvedAt` descending so the most recent resolutions appear first.
  Stream<List<LostFoundItem>> streamResolvedItems() {
    return _items
        .where('moderationStatus', isEqualTo: 'approved')
        .where('status', isEqualTo: 'resolved')
        .orderBy('resolvedAt', descending: true)
        .snapshots()
        .map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList(),
    ).handleError((error) {
      debugPrint('[ItemRepository] streamResolvedItems error: $error');
      return <LostFoundItem>[];
    });
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

  /// Streams potential matches: approved items of the opposite kind sharing
  /// the same category, excluding the current item. Used by the AI Match
  /// section on the Item Details page.
  Stream<List<LostFoundItem>> streamPotentialMatches({
    required String currentItemId,
    required ItemKind currentKind,
    String? category,
  }) {
    if (category == null || category.isEmpty) {
      return const Stream.empty();
    }
    final oppositeKind =
        currentKind == ItemKind.lost ? ItemKind.found : ItemKind.lost;
    return _items
        .where('moderationStatus', isEqualTo: 'approved')
        .where('kind', isEqualTo: oppositeKind.firestoreValue)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .where((item) => item.id != currentItemId && !item.status.isTerminal)
          .toList(),
    ).handleError((error) {
      debugPrint('[ItemRepository] streamPotentialMatches error: $error');
      return <LostFoundItem>[];
    });
  }

  /// Delete an item.
  Future<void> deleteItem(String id) async {
    await _items.doc(id).delete();
  }
}
