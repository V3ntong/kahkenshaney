import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Lifecycle of a single claim on an item (A4 — non-exclusive claims).
enum ClaimStatus {
  /// Submitted, awaiting admin review.
  submitted,

  /// Approved by an admin — the item is resolved in favor of this claimer.
  approved,

  /// Rejected (admin chose another claimant, or item already resolved).
  rejected,
}

extension ClaimStatusX on ClaimStatus {
  String get firestoreValue => name;

  String get label => switch (this) {
        ClaimStatus.submitted => 'Pending review',
        ClaimStatus.approved => 'Approved',
        ClaimStatus.rejected => 'Not approved',
      };

  static ClaimStatus fromFirestore(String? value) {
    return ClaimStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ClaimStatus.submitted,
    );
  }
}

/// One claim in the `items/{itemId}/claims` subcollection.
///
/// Written server-side only (Cloud Functions `claimItem` / `approveClaim`);
/// clients get read-only access so the UI can show how many people claimed
/// an item and which claim the current user submitted.
class ItemClaim {
  const ItemClaim({
    required this.id,
    required this.itemId,
    required this.claimerUid,
    this.claimerName,
    this.status = ClaimStatus.submitted,
    this.note,
    this.location,
    this.createdAt,
    this.decidedAt,
    this.decidedBy,
  });

  final String id;
  final String itemId;
  final String claimerUid;

  /// Snapshot of the claimer's display name (no email/phone) taken when the
  /// claim was submitted — shown to admins reviewing claims.
  final String? claimerName;
  final ClaimStatus status;
  final String? note;
  final String? location;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String? decidedBy;

  factory ItemClaim.fromMap(String id, String itemId, Map<String, dynamic> map) {
    return ItemClaim(
      id: id,
      itemId: (map['itemId'] as String?) ?? itemId,
      claimerUid: (map['claimerUid'] as String?) ?? '',
      claimerName: map['claimerName'] as String?,
      status: ClaimStatusX.fromFirestore(map['status'] as String?),
      note: map['note'] as String?,
      location: map['location'] as String?,
      createdAt: _toDate(map['createdAt']),
      decidedAt: _toDate(map['decidedAt']),
      decidedBy: map['decidedBy'] as String?,
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
