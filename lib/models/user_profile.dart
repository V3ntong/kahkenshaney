import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.fcmTokens = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final List<String> fcmTokens;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    List<String>? fcmTokens,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? '',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      fcmTokens: ((map['fcmTokens'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'fcmTokens': fcmTokens,
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
