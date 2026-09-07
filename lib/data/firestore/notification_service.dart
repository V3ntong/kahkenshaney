import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/lost_found_item.dart';

/// A single notification document.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedItemId,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String? relatedItemId;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: (map['type'] as String?) ?? '',
      relatedItemId: map['relatedItemId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'relatedItemId': relatedItemId,
      'isRead': isRead,
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

/// Firestore service for user notifications.
///
/// Data model: `users/{userId}/notifications/{notificationId}`
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notificationsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  /// Creates a notification document for a user.
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedItemId,
  }) async {
    try {
      await _notificationsCol(userId).add({
        'title': title,
        'body': body,
        'type': type,
        'relatedItemId': relatedItemId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[NotificationService] createNotification error: $e');
    }
  }

  /// Streams all notifications for a user, newest first.
  Stream<List<AppNotification>> streamNotifications(String userId) {
    return _notificationsCol(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Stream of unread notification count.
  Stream<int> streamUnreadCount(String userId) {
    return _notificationsCol(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Marks a notification as read.
  Future<void> markAsRead(String userId, String notificationId) async {
    await _notificationsCol(userId).doc(notificationId).update({'isRead': true});
  }

  /// Marks all notifications as read for a user.
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final unread = await _notificationsCol(userId)
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Creates a notification when an item's moderation status changes.
  Future<void> notifyModerationChange({
    required LostFoundItem item,
    required ModerationStatus newStatus,
  }) async {
    final (title, body) = switch (newStatus) {
      ModerationStatus.approved => (
          'Item Approved',
          'Your ${item.kind.name} item "${item.title}" has been approved and is now visible publicly.',
        ),
      ModerationStatus.rejected => (
          'Item Rejected',
          'Your ${item.kind.name} item "${item.title}" was not approved. Please contact support for details.',
        ),
      ModerationStatus.pending => (
          'Item Under Review',
          'Your ${item.kind.name} item "${item.title}" is now under review.',
        ),
    };

    await createNotification(
      userId: item.ownerUid,
      title: title,
      body: body,
      type: 'moderation_${newStatus.name}',
      relatedItemId: item.id,
    );
  }

  /// Creates a notification when an item's lifecycle status changes.
  Future<void> notifyStatusChange({
    required LostFoundItem item,
    required ItemStatus newStatus,
  }) async {
    final (title, body) = switch (newStatus) {
      ItemStatus.pendingVerification => (
          'Verification Pending',
          'Your ${item.kind.name} item "${item.title}" is pending verification.',
        ),
      ItemStatus.verified => (
          'Item Verified',
          'Your ${item.kind.name} item "${item.title}" has been verified.',
        ),
      ItemStatus.matched => (
          'Match Found!',
          'A potential match has been found for your ${item.kind.name} item "${item.title}".',
        ),
      ItemStatus.pendingClaim => (
          'Claim Submitted',
          'A claim was submitted for your ${item.kind.name} item "${item.title}" and is pending review.',
        ),
      ItemStatus.claimed => (
          'Item Claimed',
          'Your ${item.kind.name} item "${item.title}" has been claimed.',
        ),
      ItemStatus.closed => (
          'Item Archived',
          'Your ${item.kind.name} item "${item.title}" has been archived.',
        ),
      ItemStatus.resolved => (
          'Item Resolved',
          _resolvedBody(item),
        ),
      ItemStatus.open => (
          'Item Submitted',
          'Your ${item.kind.name} item "${item.title}" has been submitted.',
        ),
    };

    await createNotification(
      userId: item.ownerUid,
      title: title,
      body: body,
      type: 'status_${newStatus.name}',
      relatedItemId: item.id,
    );
  }

  /// Builds a pickup-aware body for resolved notifications.
  static String _resolvedBody(LostFoundItem item) {
    var body =
        'Your ${item.kind.name} item "${item.title}" has been resolved.';
    final parts = <String>[];
    if (item.pickupDateTime != null) {
      parts.add('on ${item.pickupDateTime}');
    }
    if (item.pickupLocation != null && item.pickupLocation!.isNotEmpty) {
      parts.add('at ${item.pickupLocation}');
    }
    if (parts.isNotEmpty) {
      body += ' You can pick it up ${parts.join(' ')}.';
    }
    return body;
  }

  /// Notifies the admin when a new report is submitted.
  Future<void> notifyAdminNewReport({
    required LostFoundItem item,
  }) async {
    try {
      final adminSnapshot = await _firestore
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) return;

      final adminUid = adminSnapshot.docs.first.id;
      final kindLabel = item.kind == ItemKind.lost ? 'Lost' : 'Found';

      await createNotification(
        userId: adminUid,
        title: 'New $kindLabel Item Report',
        body: 'A new ${item.kind.name} item "${item.title}" has been submitted and is awaiting review.',
        type: 'new_report',
        relatedItemId: item.id,
      );
    } catch (e) {
      debugPrint('[NotificationService] notifyAdminNewReport error: $e');
    }
  }
}
