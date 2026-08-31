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

  /// Looks up the real admin UID from Firestore by finding the user
  /// document with `isAdmin: true`. Returns null if not found.
  static Future<String?> lookupAdminUid(FirebaseFirestore? firestore) async {
    final db = firestore ?? FirebaseFirestore.instance;
    try {
      final snap = await db
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.id;
      }
    } catch (e) {
      debugPrint('[SupportChatService] lookupAdminUid error: $e');
    }
    return null;
  }

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
        'unreadByAdminCount': 0,
        'unreadByUserCount': 0,
      });
    }
    return userId;
  }

  /// Ensures [uid] is in the chat's participants array.
  ///
  /// Called when the admin opens a chat to guarantee they can write to it,
  /// even if the chat was created before the real admin UID was known.
  Future<void> ensureParticipant(String chatId, String uid) async {
    try {
      final doc = _chatDoc(chatId);
      final snap = await doc.get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final participants = (data['participants'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (!participants.contains(uid)) {
        await doc.update({
          'participants': FieldValue.arrayUnion([uid]),
        });
      }
    } catch (e) {
      debugPrint('[SupportChatService] ensureParticipant error: $e');
    }
  }

  // ── Send message ────────────────────────────────────────────────────────

  /// Sends a message in the user's chat thread.
  ///
  /// [chatId] is the user's UID. [senderId] is the UID of the sender
  /// (either the user or the admin). [isAdmin] indicates if the sender
  /// is the admin. [imageUrl] is an optional image attachment URL.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required bool isAdmin,
    String? imageUrl,
  }) async {
    if (text.trim().isEmpty && imageUrl == null) return;

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
      if (imageUrl != null) 'imageUrl': imageUrl,
    });

    // Update chat metadata.
    batch.update(chatRef, {
      'lastMessage': text.trim().isNotEmpty ? text.trim() : '📷 Image',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': !isAdmin, // Unread by admin if user sent it
      'unreadByUser': isAdmin, // Unread by user if admin sent it
      'unreadByAdminCount': FieldValue.increment(isAdmin ? 0 : 1),
      'unreadByUserCount': FieldValue.increment(isAdmin ? 1 : 0),
    });

    await batch.commit();
  }

  // ── Stream messages ─────────────────────────────────────────────────────

  /// Streams all messages in a chat, ordered by timestamp ascending.
  Stream<List<SupportMessage>> streamMessages(String chatId) {
    return _messagesCol(chatId)
        .orderBy('timestamp')
        .snapshots()
        .handleError((error) {
      debugPrint('[SupportChatService] streamMessages error: $error');
      return const Stream.empty();
    }).map(
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
        .handleError((error) {
      debugPrint('[SupportChatService] streamAllChats error: $error');
      return const Stream.empty();
    }).map(
          (snap) => snap.docs
              .map((doc) => SupportChat.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // ── Stream single chat ──────────────────────────────────────────────────

  /// Streams the chat document for a specific user.
  Stream<SupportChat?> streamChat(String userId) {
    return _chatDoc(userId).snapshots().handleError((error) {
      debugPrint('[SupportChatService] streamChat error: $error');
      return const Stream.empty();
    }).map(
          (doc) => doc.exists ? SupportChat.fromMap(doc.id, doc.data()!) : null,
        );
  }

  // ── Mark as read ────────────────────────────────────────────────────────

  /// Marks the chat as read by the admin.
  Future<void> markReadByAdmin(String chatId) async {
    await _chatDoc(chatId).update({
      'unreadByAdmin': false,
      'unreadByAdminCount': 0,
    });
  }

  /// Marks the chat as read by the user.
  Future<void> markReadByUser(String chatId) async {
    await _chatDoc(chatId).update({
      'unreadByUser': false,
      'unreadByUserCount': 0,
    });
  }

  // ── Peer-to-peer chat (Contact Reporter) ──────────────────────────────

  /// Generates a deterministic chat ID for a peer-to-peer conversation.
  ///
  /// Both UIDs are sorted alphabetically so the same pair always produces
  /// the same chat ID, regardless of who initiates.
  static String peerChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'peer_${sorted[0]}_${sorted[1]}';
  }

  /// Ensures a peer-to-peer chat exists between [userId] and [peerUid].
  ///
  /// Returns the chat ID. If the chat doesn't exist, it creates one with
  /// both participants. The participants array is always sorted so that
  /// `participants[0]` is the alphabetically first UID.
  Future<String> ensurePeerChat(String userId, String peerUid) async {
    final chatId = peerChatId(userId, peerUid);
    final doc = _chatDoc(chatId);
    final snap = await doc.get();
    if (!snap.exists) {
      final sorted = [userId, peerUid]..sort();
      await doc.set({
        'participants': sorted,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadByAdmin': false,
        'unreadByUser': false,
        'unreadByAdminCount': 0,
        'unreadByUserCount': 0,
        'isPeerChat': true,
      });
    }
    return chatId;
  }

  /// Sends a message in a peer-to-peer chat.
  ///
  /// [chatId] is the peer chat ID from [peerChatId]. [senderId] is the
  /// UID of the sender. Automatically determines unread routing based on
  /// participant order.
  Future<void> sendPeerMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? imageUrl,
  }) async {
    if (text.trim().isEmpty && imageUrl == null) return;

    final messagesRef = _messagesCol(chatId);
    final chatRef = _chatDoc(chatId);

    // Read participants to determine sender's position.
    final snap = await chatRef.get();
    final data = snap.data();
    if (data == null) return;
    final participants = (data['participants'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (participants.length < 2) return;

    final isSenderA = senderId == participants[0];

    final batch = _firestore.batch();

    batch.set(messagesRef.doc(), {
      'senderId': senderId,
      'text': text.trim(),
      'isAdmin': false,
      'timestamp': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    });

    batch.update(chatRef, {
      'lastMessage': text.trim().isNotEmpty ? text.trim() : '📷 Image',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': !isSenderA,
      'unreadByUser': isSenderA,
      'unreadByAdminCount': FieldValue.increment(isSenderA ? 0 : 1),
      'unreadByUserCount': FieldValue.increment(isSenderA ? 1 : 0),
    });

    await batch.commit();
  }

  /// Marks a peer chat as read by the given user.
  ///
  /// Determines whether the user is participant A or B and resets the
  /// corresponding unread counter.
  Future<void> markReadByPeer(String chatId, String uid) async {
    final snap = await _chatDoc(chatId).get();
    final data = snap.data();
    if (data == null) return;
    final participants = (data['participants'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (participants.length < 2) return;

    final isParticipantA = uid == participants[0];
    await _chatDoc(chatId).update({
      if (isParticipantA) 'unreadByAdmin': false,
      if (isParticipantA) 'unreadByAdminCount': 0,
      if (!isParticipantA) 'unreadByUser': false,
      if (!isParticipantA) 'unreadByUserCount': 0,
    });
  }

  /// Streams the peer chat document for a conversation between two users.
  Stream<SupportChat?> streamPeerChat(String uid1, String uid2) {
    return streamChat(peerChatId(uid1, uid2));
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
