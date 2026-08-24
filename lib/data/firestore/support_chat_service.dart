import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/support_chat.dart';
import '../../models/support_message.dart';

/// Firestore service for 1-on-1 support chats between users and admin.
///
/// Data model:
/// - `chats/{userId}` — one chat document per user (document ID = user UID)
/// - `chats/{userId}/messages/{messageId}` — messages subcollection
///
/// The admin UID is passed via [adminUid] constructor parameter. If not
/// provided, it defaults to the hardcoded admin email lookup.
class SupportChatService {
  SupportChatService({
    FirebaseFirestore? firestore,
    required this.adminUid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String adminUid;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  // ── Chat helpers ────────────────────────────────────────────────────────

  /// Reference to a specific chat document.
  DocumentReference<Map<String, dynamic>> _chatDoc(String userId) =>
      _chats.doc(userId);

  /// Reference to the messages subcollection of a chat.
  CollectionReference<Map<String, dynamic>> _messagesCol(String userId) =>
      _chatDoc(userId).collection('messages');

  /// Ensures a chat document exists for [userId].
  ///
  /// If the document doesn't exist, it creates one with default values.
  /// Returns the chat ID (which is the userId).
  Future<String> ensureChat(String userId) async {
    final doc = _chatDoc(userId);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'participants': [userId, adminUid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadByAdmin': false,
        'unreadByUser': false,
      });
    }
    return userId;
  }

  // ── Send message ────────────────────────────────────────────────────────

  /// Sends a message in the user's chat thread.
  ///
  /// [chatId] is the user's UID. [senderId] is the UID of the sender
  /// (either the user or the admin). [isAdmin] indicates if the sender
  /// is the admin.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required bool isAdmin,
  }) async {
    if (text.trim().isEmpty) return;

    final messagesRef = _messagesCol(chatId);
    final chatRef = _chatDoc(chatId);

    // Use a batch to atomically add message + update chat metadata.
    final batch = _firestore.batch();

    // Add message to subcollection.
    batch.set(messagesRef.doc(), {
      'senderId': senderId,
      'text': text.trim(),
      'isAdmin': isAdmin,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update chat metadata.
    batch.update(chatRef, {
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': !isAdmin, // Unread by admin if user sent it
      'unreadByUser': isAdmin, // Unread by user if admin sent it
    });

    await batch.commit();
  }

  // ── Stream messages ─────────────────────────────────────────────────────

  /// Streams all messages in a chat, ordered by timestamp ascending.
  Stream<List<SupportMessage>> streamMessages(String chatId) {
    return _messagesCol(chatId)
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SupportMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // ── Stream all chats (admin inbox) ──────────────────────────────────────

  /// Streams all chat documents, sorted by lastMessageAt descending.
  ///
  /// Used by the admin inbox to show all user conversations.
  Stream<List<SupportChat>> streamAllChats() {
    return _chats
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SupportChat.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // ── Stream single chat ──────────────────────────────────────────────────

  /// Streams the chat document for a specific user.
  Stream<SupportChat?> streamChat(String userId) {
    return _chatDoc(userId).snapshots().map(
          (doc) => doc.exists ? SupportChat.fromMap(doc.id, doc.data()!) : null,
        );
  }

  // ── Mark as read ────────────────────────────────────────────────────────

  /// Marks the chat as read by the admin.
  Future<void> markReadByAdmin(String chatId) async {
    await _chatDoc(chatId).update({'unreadByAdmin': false});
  }

  /// Marks the chat as read by the user.
  Future<void> markReadByUser(String chatId) async {
    await _chatDoc(chatId).update({'unreadByUser': false});
  }

  // ── Get user display name ───────────────────────────────────────────────

  /// Fetches the display name of a user from the `users` collection.
  Future<String> getUserDisplayName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return 'User';
      final name = doc.data()!['displayName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
      final email = doc.data()!['email'] as String?;
      if (email != null && email.trim().isNotEmpty) {
        // Return part before @ as a fallback name.
        return email.trim().split('@').first;
      }
      return 'User';
    } catch (e) {
      debugPrint('[SupportChatService] getUserDisplayName error: $e');
      return 'User';
    }
  }
}
