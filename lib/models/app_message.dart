import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class AppMessage {
  const AppMessage({
    required this.itemId,
    required this.senderUid,
    required this.receiverUid,
    required this.text,
    this.id,
    this.read,
    this.createdAt,
  });

  final String? id;
  final String itemId;
  final String senderUid;
  final String receiverUid;
  final String text;
  final bool? read;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'text': text,
      'read': read ?? false,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  factory AppMessage.fromMap(String id, Map<String, dynamic> map) {
    return AppMessage(
      id: id,
      itemId: (map['itemId'] as String?) ?? '',
      senderUid: (map['senderUid'] as String?) ?? '',
      receiverUid: (map['receiverUid'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      read: map['read'] as bool?,
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : null,
    );
  }
}