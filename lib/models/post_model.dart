import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// A single post (photo + caption) uploaded by a user.
class PostModel {
  const PostModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.caption,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final String caption;
  final DateTime? createdAt;

  PostModel copyWith({
    String? imageUrl,
    String? caption,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt,
    );
  }

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      userId: (map['userId'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      caption: (map['caption'] as String?) ?? '',
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'caption': caption,
      'createdAt': createdAt,
    };
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
