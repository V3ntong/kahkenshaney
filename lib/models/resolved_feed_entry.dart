import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'lost_found_item.dart';

/// A public entry in the homepage "Recently Resolved" feed
/// (`resolvedFeed/{itemId}`).
///
/// Published server-side (Cloud Function) when an item's claim is approved
/// and the item reaches a terminal status. Deliberately PII-free: display
/// names only — never email, phone, or user IDs.
class ResolvedFeedEntry {
  const ResolvedFeedEntry({
    required this.itemId,
    required this.title,
    required this.description,
    required this.kind,
    this.category,
    this.imageUrl,
    this.foundAt,
    this.foundLocation,
    this.finderName,
    this.claimerName,
    this.claimAt,
    this.claimLocation,
    this.resolvedAt,
  });

  final String itemId;
  final String title;
  final String description;
  final ItemKind kind;
  final String? category;
  final String? imageUrl;

  /// When the item was found (report event date, else report creation).
  final DateTime? foundAt;
  final String? foundLocation;

  /// Display name of the person who found/reported the item.
  final String? finderName;

  /// Display name of the person whose claim was approved.
  final String? claimerName;
  final DateTime? claimAt;
  final String? claimLocation;
  final DateTime? resolvedAt;

  factory ResolvedFeedEntry.fromMap(String id, Map<String, dynamic> map) {
    return ResolvedFeedEntry(
      itemId: (map['itemId'] as String?) ?? id,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      kind: ItemKindX.fromFirestore(map['kind'] as String?),
      category: map['category'] as String?,
      imageUrl: map['imageUrl'] as String?,
      foundAt: _toDate(map['foundAt']),
      foundLocation: map['foundLocation'] as String?,
      finderName: map['finderName'] as String?,
      claimerName: map['claimerName'] as String?,
      claimAt: _toDate(map['claimAt']),
      claimLocation: map['claimLocation'] as String?,
      resolvedAt: _toDate(map['resolvedAt']),
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
