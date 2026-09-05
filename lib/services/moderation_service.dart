import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ContentReport {
  const ContentReport({
    required this.id,
    required this.reporterUid,
    required this.reportedUserId,
    this.reportedItemId,
    required this.reason,
    this.description,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String reporterUid;
  final String reportedUserId;
  final String? reportedItemId;
  final String reason;
  final String? description;
  final String status;
  final DateTime? createdAt;

  factory ContentReport.fromMap(String id, Map<String, dynamic> map) {
    return ContentReport(
      id: id,
      reporterUid: (map['reporterUid'] as String?) ?? '',
      reportedUserId: (map['reportedUserId'] as String?) ?? '',
      reportedItemId: map['reportedItemId'] as String?,
      reason: (map['reason'] as String?) ?? '',
      description: map['description'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterUid': reporterUid,
      'reportedUserId': reportedUserId,
      'reportedItemId': reportedItemId,
      'reason': reason,
      'description': description,
      'status': status,
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

class ModerationService {
  ModerationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reportsCol =>
      _firestore.collection('moderation_reports');

  CollectionReference<Map<String, dynamic>> _blockedUsersCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('blocked_users');

  DocumentReference<Map<String, dynamic>> _notificationPrefsDoc(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('notifications');

  Future<void> reportContent({
    required String reporterUid,
    required String reportedUserId,
    String? reportedItemId,
    required String reason,
    String? description,
  }) async {
    try {
      await _reportsCol.add({
        'reporterUid': reporterUid,
        'reportedUserId': reportedUserId,
        'reportedItemId': reportedItemId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ModerationService] reportContent error: $e');
    }
  }

  Stream<List<ContentReport>> streamReports() {
    return _reportsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ContentReport.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> resolveReport(String reportId) async {
    try {
      await _reportsCol.doc(reportId).update({'status': 'resolved'});
    } catch (e) {
      debugPrint('[ModerationService] resolveReport error: $e');
    }
  }

  Stream<int> streamPendingReportCount() {
    return _reportsCol
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> blockUser({
    required String blockerUid,
    required String blockedUid,
  }) async {
    try {
      await _blockedUsersCol(blockerUid).doc(blockedUid).set({
        'blockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ModerationService] blockUser error: $e');
    }
  }

  Future<void> unblockUser({
    required String blockerUid,
    required String blockedUid,
  }) async {
    try {
      await _blockedUsersCol(blockerUid).doc(blockedUid).delete();
    } catch (e) {
      debugPrint('[ModerationService] unblockUser error: $e');
    }
  }

  Stream<List<String>> streamBlockedUsers(String blockerUid) {
    return _blockedUsersCol(blockerUid).snapshots().map(
          (snap) => snap.docs.map((doc) => doc.id).toList(),
        );
  }

  Future<bool> isBlocked({
    required String blockerUid,
    required String blockedUid,
  }) async {
    try {
      final doc = await _blockedUsersCol(blockerUid).doc(blockedUid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[ModerationService] isBlocked error: $e');
      return false;
    }
  }

  Future<bool> isMutuallyBlocked({
    required String uid1,
    required String uid2,
  }) async {
    try {
      final a = await isBlocked(blockerUid: uid1, blockedUid: uid2);
      if (a) return true;
      return await isBlocked(blockerUid: uid2, blockedUid: uid1);
    } catch (e) {
      debugPrint('[ModerationService] isMutuallyBlocked error: $e');
      return false;
    }
  }

  static const Map<String, bool> _defaultPrefs = {
    'pushEnabled': true,
    'itemMatchAlerts': true,
    'chatMessages': true,
    'adminAnnouncements': true,
  };

  Future<void> updateNotificationPreferences({
    required String uid,
    required Map<String, bool> prefs,
  }) async {
    try {
      await _notificationPrefsDoc(uid).set(prefs, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ModerationService] updateNotificationPreferences error: $e');
    }
  }

  Stream<Map<String, bool>> streamNotificationPreferences(String uid) {
    return _notificationPrefsDoc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return Map<String, bool>.from(_defaultPrefs);
      }
      final data = doc.data()!;
      return _defaultPrefs.map((key, value) {
        return MapEntry(key, (data[key] as bool?) ?? value);
      });
    });
  }

  Future<Map<String, bool>> getNotificationPreferences(String uid) async {
    try {
      final doc = await _notificationPrefsDoc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return Map<String, bool>.from(_defaultPrefs);
      }
      final data = doc.data()!;
      return _defaultPrefs.map((key, value) {
        return MapEntry(key, (data[key] as bool?) ?? value);
      });
    } catch (e) {
      debugPrint('[ModerationService] getNotificationPreferences error: $e');
      return Map<String, bool>.from(_defaultPrefs);
    }
  }
}
