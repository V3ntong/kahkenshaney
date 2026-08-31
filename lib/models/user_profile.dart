import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.fcmTokens = const [],
    this.reportsCount = 0,
    this.foundCount = 0,
    this.lostCount = 0,
    this.bio,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final List<String> fcmTokens;
  final int reportsCount;
  final int foundCount;
  final int lostCount;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    List<String>? fcmTokens,
    int? reportsCount,
    int? foundCount,
    int? lostCount,
    String? bio,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      reportsCount: reportsCount ?? this.reportsCount,
      foundCount: foundCount ?? this.foundCount,
      lostCount: lostCount ?? this.lostCount,
      bio: bio ?? this.bio,
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
      reportsCount: (map['reportsCount'] as num?)?.toInt() ?? 0,
      foundCount: (map['foundCount'] as num?)?.toInt() ?? 0,
      lostCount: (map['lostCount'] as num?)?.toInt() ?? 0,
      bio: map['bio'] as String?,
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
      'reportsCount': reportsCount,
      'foundCount': foundCount,
      'lostCount': lostCount,
      'bio': bio,
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
