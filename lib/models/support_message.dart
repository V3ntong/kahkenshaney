import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// A single message within a support chat.
///
/// Stored under `chats/{chatId}/messages/{messageId}`.
class SupportMessage {
  const SupportMessage({
    required this.senderId,
    required this.text,
    this.id,
    this.isAdmin = false,
    this.timestamp,
    this.imageUrl,
  });

  final String? id;
  final String senderId;
  final String text;
  final bool isAdmin;
  final DateTime? timestamp;
  final String? imageUrl;

  factory SupportMessage.fromMap(String id, Map<String, dynamic> map) {
    return SupportMessage(
      id: id,
      senderId: (map['senderId'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      isAdmin: map['isAdmin'] as bool? ?? false,
      timestamp: _toDate(map['timestamp']),
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'isAdmin': isAdmin,
      'timestamp': timestamp,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
