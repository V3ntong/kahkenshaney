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

enum ItemStatus { open, matched, closed }

extension ItemStatusX on ItemStatus {
  String get firestoreValue => name;

  static ItemStatus fromFirestore(String? value) {
    return ItemStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ItemStatus.open,
    );
  }
}

class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.ownerUid,
    this.location,
    this.storageLocation,
    this.status = ItemStatus.open,
    this.media = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ItemKind kind;
  final String title;
  final String description;
  final String ownerUid;
  final String? location;

  /// Where a found item is being kept until its owner claims it.
  final String? storageLocation;

  final ItemStatus status;
  final List<String> media;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LostFoundItem copyWith({
    String? title,
    String? description,
    String? location,
    String? storageLocation,
    ItemStatus? status,
    List<String>? media,
  }) {
    return LostFoundItem(
      id: id,
      kind: kind,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerUid: ownerUid,
      location: location ?? this.location,
      storageLocation: storageLocation ?? this.storageLocation,
      status: status ?? this.status,
      media: media ?? this.media,
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
      location: map['location'] as String?,
      storageLocation: map['storageLocation'] as String?,
      status: ItemStatusX.fromFirestore(map['status'] as String?),
      media: ((map['media'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
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
      'location': location,
      'storageLocation': storageLocation,
      'status': status.firestoreValue,
      'media': media,
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
