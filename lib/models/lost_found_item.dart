import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum ItemKind { lost, found }

extension ItemKindX on ItemKind {
  String get firestoreValue => name;

  static ItemKind fromFirestore(String? value) {
    return ItemKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => ItemKind.lost,
    );
  }
}

enum ItemStatus {
  open,
  pendingVerification,
  verified,
  matched,
  pendingClaim,
  claimed,
  resolved,
  closed,
}

extension ItemStatusX on ItemStatus {
  String get firestoreValue => name;

  String get label => switch (this) {
        ItemStatus.open => 'Submitted',
        ItemStatus.pendingVerification => 'Pending Verification',
        ItemStatus.verified => 'Verified',
        ItemStatus.matched => 'Matched',
        ItemStatus.pendingClaim => 'Pending Claim',
        ItemStatus.claimed => 'Claimed',
        ItemStatus.resolved => 'Resolved',
        ItemStatus.closed => 'Archived',
      };

  String get shortLabel => switch (this) {
        ItemStatus.open => 'Submitted',
        ItemStatus.pendingVerification => 'Pending',
        ItemStatus.verified => 'Verified',
        ItemStatus.matched => 'Matched',
        ItemStatus.pendingClaim => 'Claim Pending',
        ItemStatus.claimed => 'Claimed',
        ItemStatus.resolved => 'Resolved',
        ItemStatus.closed => 'Archived',
      };

  /// Returns true if this status is a "final" state (item is done).
  bool get isTerminal =>
      this == ItemStatus.claimed ||
      this == ItemStatus.resolved ||
      this == ItemStatus.closed;

  static ItemStatus fromFirestore(String? value) {
    return ItemStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ItemStatus.open,
    );
  }
}

/// Moderation status — controls public visibility of an item.
enum ModerationStatus { pending, approved, rejected }

extension ModerationStatusX on ModerationStatus {
  String get firestoreValue => name;

  String get label => switch (this) {
        ModerationStatus.pending => 'Pending Review',
        ModerationStatus.approved => 'Approved',
        ModerationStatus.rejected => 'Rejected',
      };

  String get shortLabel => switch (this) {
        ModerationStatus.pending => 'Pending',
        ModerationStatus.approved => 'Approved',
        ModerationStatus.rejected => 'Rejected',
      };

  static ModerationStatus fromFirestore(String? value) {
    return ModerationStatus.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ModerationStatus.pending,
    );
  }
}

/// A persisted smart-match candidate (stored on the item document so match
/// scores can be displayed without recomputation on every page load).
class ItemMatchScore {
  const ItemMatchScore({
    required this.itemId,
    required this.title,
    required this.kind,
    required this.score,
    this.matchedAt,
  });

  final String itemId;
  final String title;
  final ItemKind kind;

  /// Similarity 0–100 (computed server-side by the matching Cloud Function).
  final int score;
  final DateTime? matchedAt;

  factory ItemMatchScore.fromMap(Map<String, dynamic> map) {
    return ItemMatchScore(
      itemId: (map['itemId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      kind: ItemKindX.fromFirestore(map['kind'] as String?),
      score: ((map['score'] as num?) ?? 0).round(),
      matchedAt: _toDate(map['matchedAt']),
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'title': title,
      'kind': kind.firestoreValue,
      'score': score,
      'matchedAt': matchedAt,
    };
  }
}

/// A single entry in the status change history.
class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.status,
    required this.changedAt,
    this.changedBy,
  });

  final String status;
  final DateTime? changedAt;
  final String? changedBy;

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      status: (map['status'] as String?) ?? '',
      changedAt: _toDate(map['changedAt']),
      changedBy: map['changedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'changedAt': changedAt,
      'changedBy': changedBy,
    };
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}

class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.ownerUid,
    this.reportedBy = '',
    this.category,
    this.location,
    this.storageLocation,
    this.status = ItemStatus.open,
    this.moderationStatus = ModerationStatus.pending,
    this.statusHistory = const [],
    this.media = const [],
    this.imageUrl,
    this.storagePath,
    this.matchedItemId,
    this.claimedBy,
    this.resolvedByAdminId,
    this.resolvedAt,
    this.pickupDateTime,
    this.pickupLocation,
    this.matchScores = const [],
    this.eventDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ItemKind kind;
  final String title;
  final String description;
  final String ownerUid;

  /// The UID of the user who originally reported the item. Set at creation
  /// time and enforced by Firestore rules + the server-side claim check.
  final String reportedBy;
  final String? category;
  final String? location;
  final String? storageLocation;
  final ItemStatus status;
  final ModerationStatus moderationStatus;
  final List<StatusHistoryEntry> statusHistory;
  final List<String> media;
  final String? imageUrl;
  final String? storagePath;

  /// The item ID this item is matched with (for matched status).
  final String? matchedItemId;

  /// The UID of the user who submitted a claim (status `pendingClaim`).
  final String? claimedBy;

  /// The UID of the admin who approved/resolved the claim.
  final String? resolvedByAdminId;

  /// The timestamp when the item was resolved.
  final DateTime? resolvedAt;

  /// When the item can be picked up (null = available now).
  final DateTime? pickupDateTime;

  /// Where the item can be picked up (null = use storageLocation).
  final String? pickupLocation;

  /// Persisted smart-match candidates, ranked by [ItemMatchScore.score].
  final List<ItemMatchScore> matchScores;

  /// The date the item was lost/found (collected by the report forms). Used
  /// by smart matching for date-range proximity scoring.
  final DateTime? eventDate;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether [uid] may submit a claim for this item.
  ///
  /// Claimability rule (mirrors the server-side `claimItem` Cloud Function):
  ///   1. Caller must be signed-in and must NOT be an admin.
  ///   2. Caller must NOT be the item owner (`ownerUid`) or the original
  ///      reporter (`reportedBy`).
  ///   3. Item status must be non-terminal (not `claimed`, `resolved`, or
  ///      `closed`) and not already `pendingClaim`.
  ///   4. No existing claim (`claimedBy` must be null or empty).
  ///
  /// This is a UI convenience — the server is the source of truth.
  bool canBeClaimedBy(String uid, {bool isAdmin = false}) {
    if (uid.isEmpty || isAdmin) return false;
    if (uid == ownerUid || (reportedBy.isNotEmpty && uid == reportedBy)) {
      return false;
    }
    if (status.isTerminal || status == ItemStatus.pendingClaim) return false;
    if (claimedBy != null && claimedBy!.isNotEmpty) return false;
    return true;
  }

  String? get displayUrl => imageUrl ?? (media.isNotEmpty ? media.first : null);
  bool get isPublic => moderationStatus == ModerationStatus.approved;

  LostFoundItem copyWith({
    String? title,
    String? description,
    String? category,
    String? location,
    String? storageLocation,
    ItemStatus? status,
    ModerationStatus? moderationStatus,
    List<StatusHistoryEntry>? statusHistory,
    List<String>? media,
    String? imageUrl,
    String? storagePath,
    String? matchedItemId,
    String? claimedBy,
    String? resolvedByAdminId,
    DateTime? resolvedAt,
    DateTime? pickupDateTime,
    String? pickupLocation,
    List<ItemMatchScore>? matchScores,
    DateTime? eventDate,
  }) {
    return LostFoundItem(
      id: id,
      kind: kind,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerUid: ownerUid,
      reportedBy: reportedBy,
      category: category ?? this.category,
      location: location ?? this.location,
      storageLocation: storageLocation ?? this.storageLocation,
      status: status ?? this.status,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      statusHistory: statusHistory ?? this.statusHistory,
      media: media ?? this.media,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      matchedItemId: matchedItemId ?? this.matchedItemId,
      claimedBy: claimedBy ?? this.claimedBy,
      resolvedByAdminId: resolvedByAdminId ?? this.resolvedByAdminId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      pickupDateTime: pickupDateTime ?? this.pickupDateTime,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      matchScores: matchScores ?? this.matchScores,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory LostFoundItem.fromMap(String id, Map<String, dynamic> map) {
    return LostFoundItem(
      id: id,
      kind: ItemKindX.fromFirestore(map['kind'] as String?),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      ownerUid: (map['ownerUid'] as String?) ?? '',
      reportedBy: (map['reportedBy'] as String?) ?? '',
      category: map['category'] as String?,
      location: map['location'] as String?,
      storageLocation: map['storageLocation'] as String?,
      status: ItemStatusX.fromFirestore(map['status'] as String?),
      moderationStatus:
          ModerationStatusX.fromFirestore(map['moderationStatus'] as String?),
      statusHistory: ((map['statusHistory'] as List?) ?? const [])
          .map((e) => StatusHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      media: ((map['media'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      imageUrl: map['imageUrl'] as String?,
      storagePath: map['storagePath'] as String?,
      matchedItemId: map['matchedItemId'] as String?,
      claimedBy: map['claimedBy'] as String?,
      resolvedByAdminId: map['resolvedByAdminId'] as String?,
      resolvedAt: _toDate(map['resolvedAt']),
      pickupDateTime: _toDate(map['pickupDateTime']),
      pickupLocation: map['pickupLocation'] as String?,
      matchScores: ((map['matchScores'] as List?) ?? const [])
          .map((e) => ItemMatchScore.fromMap(e as Map<String, dynamic>))
          .toList(),
      eventDate: _toDate(map['eventDate']),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kind': kind.firestoreValue,
      'title': title,
      'description': description,
      'ownerUid': ownerUid,
      'reportedBy': reportedBy,
      'category': category,
      'location': location,
      'storageLocation': storageLocation,
      'status': status.name,
      'moderationStatus': moderationStatus.name,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'media': media,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'matchedItemId': matchedItemId,
      'claimedBy': claimedBy,
      'resolvedByAdminId': resolvedByAdminId,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'pickupDateTime': pickupDateTime?.toIso8601String(),
      'pickupLocation': pickupLocation,
      'matchScores': matchScores.map((e) => e.toMap()).toList(),
      'eventDate': eventDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
