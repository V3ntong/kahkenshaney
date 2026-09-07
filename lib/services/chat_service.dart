import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// A single turn in the chatbot conversation.
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime? timestamp;

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp?.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] as String? ?? '',
      isUser: map['isUser'] as bool? ?? false,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : null,
    );
  }
}

/// Chatbot backend that persists conversation history to Firestore and
/// routes Gemini requests through the server-side `kashtep` Cloud Function
/// so the API key never leaves the server.
///
/// Firestore shape: `chatbot_history/{userId}` — a single document whose
/// `messages` array holds the conversation. Per-user access is granted via
/// Firestore rules (see firestore.rules).
class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  static const String _collection = 'chatbot_history';
  static const String _region = 'us-central1';

  /// The in-memory working copy of the conversation. Kept in sync with
  /// Firestore so the UI can render immediately while async persistence
  /// happens in the background.
  final List<ChatMessage> _history = [];

  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Clears both the in-memory history and the persisted Firestore document.
  void clearHistory() {
    _history.clear();
  }

  /// Add user message to history immediately (for UI display).
  void addUserMessage(String message) {
    _history.add(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
  }

  /// Add assistant response to history (for UI display).
  void addAssistantMessage(String message) {
    _history.add(ChatMessage(
      text: message,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  /// Loads persisted history from Firestore on startup so the conversation
  /// context is restored when the chatbot is reopened.
  Future<void> loadHistory(String userId) async {
    if (userId.isEmpty) return;
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return;
      final raw = doc.data()?['messages'] as List<dynamic>?;
      if (raw == null || raw.isEmpty) return;
      _history.clear();
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        _history.add(ChatMessage.fromMap(entry));
      }
    } catch (e) {
      debugPrint('[ChatService] loadHistory error: $e');
    }
  }

  /// Persists the current in-memory history to Firestore. Called after each
  /// successful exchange so the conversation survives app restarts.
  Future<void> saveHistory(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _firestore.collection(_collection).doc(userId).set({
        'messages': _history.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] saveHistory error: $e');
    }
  }

  /// Sends [message] to the server-side chatbot Cloud Function and returns
  /// the assistant reply. The API key stays server-side.
  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';

    // Add the user message to history if it isn't already the last message.
    if (_history.isEmpty ||
        _history.last.text != trimmed ||
        !_history.last.isUser) {
      addUserMessage(trimmed);
    }

    final fn = _functions ?? _defaultFunctions();

    try {
      final callable = fn.httpsCallable('kashtep');
      final response = await callable.call<Map<String, dynamic>>({
        'message': trimmed,
        'history': _history.take(20).map((m) => {
          'role': m.isUser ? 'user' : 'model',
          'text': m.text,
        }).toList(),
      });

      final reply = response.data['reply'] as String? ?? '';
      if (reply.isNotEmpty) {
        addAssistantMessage(reply);
      }
      return reply;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[ChatService] Cloud Function error: ${e.code} — ${e.message}');
      return _userFacingError(e.code);
    } catch (e) {
      debugPrint('[ChatService] Unexpected error: $e');
      return 'The AI assistant could not generate a response. Please try again.';
    }
  }

  FirebaseFunctions _defaultFunctions() {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not configured on this platform.');
    }
    return FirebaseFunctions.instanceFor(region: _region);
  }

  String _userFacingError(String? code) {
    switch (code) {
      case 'unauthenticated':
        return 'You are not signed in. Please log in to use the assistant.';
      case 'permission-denied':
        return 'You do not have permission to use the assistant.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'deadline-exceeded':
        return 'The assistant is taking too long. Please try again.';
      case 'not-found':
        return 'The chat service is currently unavailable. Please try again later.';
      case 'internal':
        return 'Something went wrong on our end. Please try again.';
      default:
        return 'The AI assistant could not generate a response. Please try again.';
    }
  }
}
