import 'package:cloud_firestore/cloud_firestore.dart';

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

  Stream<List<LostFoundItem>> streamItems({ItemKind? kind}) {
    Query<Map<String, dynamic>> query = _items
        .orderBy('createdAt', descending: true);
    if (kind != null) {
      query = query.where('kind', isEqualTo: kind.firestoreValue);
    }
    return query.snapshots().map(
      (snap) => snap.docs
          .map((doc) => LostFoundItem.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> updateItem(LostFoundItem item) async {
    await _items.doc(item.id).update(item.toMap());
  }

  Future<void> deleteItem(String id) async {
    await _items.doc(id).delete();
  }
}
