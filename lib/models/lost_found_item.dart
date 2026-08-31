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
  claimed,
  closed,
}

extension ItemStatusX on ItemStatus {
  String get firestoreValue => name;

  String get label => switch (this) {
        ItemStatus.open => 'Submitted',
        ItemStatus.pendingVerification => 'Pending Verification',
        ItemStatus.verified => 'Verified',
        ItemStatus.matched => 'Matched',
        ItemStatus.claimed => 'Claimed',
        ItemStatus.closed => 'Archived',
      };

  String get shortLabel => switch (this) {
        ItemStatus.open => 'Submitted',
        ItemStatus.pendingVerification => 'Pending',
        ItemStatus.verified => 'Verified',
        ItemStatus.matched => 'Matched',
        ItemStatus.claimed => 'Claimed',
        ItemStatus.closed => 'Archived',
      };

  /// Returns true if this status is a "final" state (item is done).
  bool get isTerminal => this == ItemStatus.claimed || this == ItemStatus.closed;

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
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ItemKind kind;
  final String title;
  final String description;
  final String ownerUid;
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

  final DateTime? createdAt;
  final DateTime? updatedAt;

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
  }) {
    return LostFoundItem(
      id: id,
      kind: kind,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerUid: ownerUid,
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
      'category': category,
      'location': location,
      'storageLocation': storageLocation,
      'status': status.firestoreValue,
      'moderationStatus': moderationStatus.firestoreValue,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'media': media,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'matchedItemId': matchedItemId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
