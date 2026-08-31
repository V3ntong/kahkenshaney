import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// A 1-on-1 support chat between a user and the admin.
///
/// Document ID is the user's UID, guaranteeing one thread per user.
/// Stored under `chats/{userId}`.
class SupportChat {
  const SupportChat({
    required this.id,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadByAdmin = false,
    this.unreadByUser = false,
    this.unreadByAdminCount = 0,
    this.unreadByUserCount = 0,
  });

  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool unreadByAdmin;
  final bool unreadByUser;
  final int unreadByAdminCount;
  final int unreadByUserCount;

  /// The UID of the non-admin participant (the user).
  String get userId => id;

  factory SupportChat.fromMap(String id, Map<String, dynamic> map) {
    return SupportChat(
      id: id,
      participants: ((map['participants'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      lastMessage: (map['lastMessage'] as String?) ?? '',
      lastMessageAt: _toDate(map['lastMessageAt']),
      unreadByAdmin: map['unreadByAdmin'] as bool? ?? false,
      unreadByUser: map['unreadByUser'] as bool? ?? false,
      unreadByAdminCount: (map['unreadByAdminCount'] as num?)?.toInt() ?? 0,
      unreadByUserCount: (map['unreadByUserCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'unreadByAdmin': unreadByAdmin,
      'unreadByUser': unreadByUser,
      'unreadByAdminCount': unreadByAdminCount,
      'unreadByUserCount': unreadByUserCount,
    };
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
