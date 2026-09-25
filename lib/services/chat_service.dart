import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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

/// Thrown when the assistant call fails. Carries a message that is already
/// safe to show to the user, plus whether retrying makes sense.
class ChatSendException implements Exception {
  const ChatSendException(this.message, {this.code, this.retryable = true});

  final String message;
  final String? code;
  final bool retryable;

  @override
  String toString() => message;
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
  ///
  /// Throws [ChatSendException] when the call fails, so the UI can keep the
  /// user's message on screen and offer a retry instead of rendering an
  /// error string as if the assistant had replied.
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

    // Refresh the App Check token right before the call so a stale/expired
    // token (the usual cause of `app-check-unauthorized` / unexpected
    // `not-found` responses) is never sent to the backend.
    await _refreshAppCheckToken();

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

      // An App Check enforcement failure on a callable can surface as
      // NOT_FOUND / PERMISSION_DENIED rather than a dedicated code.
      final appCheckActive = await _isAppCheckActive();
      if (!appCheckActive && _isAppCheckShaped(e.code)) {
        throw ChatSendException(
          'Unable to verify app security. Please update the app and try again.',
          code: e.code,
          retryable: false,
        );
      }

      throw ChatSendException(
        _userFacingError(e.code),
        code: e.code,
        retryable: _isRetryable(e.code),
      );
    } on ChatSendException {
      rethrow;
    } catch (e) {
      debugPrint('[ChatService] Unexpected error: $e');
      throw const ChatSendException(
        'The AI assistant could not generate a response. Please try again.',
      );
    }
  }

  /// Best-effort App Check token refresh. Failure is non-fatal: the SDK
  /// falls back to its cached token (and the backend may not enforce App
  /// Check at all).
  Future<void> _refreshAppCheckToken() async {
    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (e) {
      debugPrint('[ChatService] App Check token refresh failed: $e');
    }
  }

  /// Codes that App Check enforcement commonly produces for callables.
  bool _isAppCheckShaped(String code) {
    return code == 'not-found' || code == 'app-check-unauthorized';
  }

  bool _isRetryable(String code) {
    return code == 'deadline-exceeded' ||
        code == 'unavailable' ||
        code == 'resource-exhausted' ||
        code == 'internal' ||
        code == 'unknown';
  }

  /// Checks whether App Check was successfully activated at startup.
  Future<bool> _isAppCheckActive() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(false);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
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
      case 'unavailable':
        return 'The assistant is temporarily unavailable. Please try again.';
      case 'failed-precondition':
        return 'The assistant is not configured yet. Please try again later.';
      case 'invalid-argument':
        return 'That message is too long. Please shorten it and try again.';
      case 'not-found':
        return 'The chat service is currently unavailable. Please try again later.';
      case 'internal':
        return 'Something went wrong on our end. Please try again.';
      default:
        return 'The AI assistant could not generate a response. Please try again.';
    }
  }
}
