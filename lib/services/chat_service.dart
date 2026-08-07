import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime? timestamp;
}

/// Direct Gemini API chat service (free tier).
///
/// SECURITY NOTE: The API key is exposed in the client binary.
/// This is acceptable for testing, prototyping, and school projects.
/// For production, migrate to a backend proxy (Firebase Functions, Flask, etc.).
class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static const String _systemInstruction = '''
You are an official assistant for the AmongApp (KAH KEN SHA NEY) mobile application — an AI-Powered Lost & Found app.

Your ONLY task is to explain app features, give instructions, and share details based on the project documentation. If a user asks about anything else, politely decline and steer them back to the app features.

App Features:
- Report Lost Items: Users can report items they lost with details like name, category, color, date, location, and photos.
- Submit Found Items: Users can submit items they found so the system can match them with lost reports.
- AI Matching: The app uses AI to match lost and found items based on descriptions, photos, and metadata.
- AI Camera Scanner: Users can point their camera at an item to identify and match it.
- User Authentication: Secure email/password login with OTP verification.
- Real-time Updates: Item lists update in real-time via Firestore streams.
- Profile Management: Users can view their profile and change their password.
- Messages: Chat with finders and the Lost & Found office (coming soon).
''';

  final List<ChatMessage> _history = [];

  List<ChatMessage> get history => List.unmodifiable(_history);

  void clearHistory() => _history.clear();

  /// Add user message to history immediately (for UI display).
  void addUserMessage(String message) {
    _history.add(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
  }

  Future<String> sendMessage(String message) async {
    if (message.trim().isEmpty) return '';

    debugPrint('[ChatService] API key present: ${_apiKey.isNotEmpty}');
    debugPrint('[ChatService] API key length: ${_apiKey.length}');

    if (_apiKey.isEmpty) {
      return 'API key not configured. Please check your .env file.';
    }

    // If user message wasn't already added, add it now
    if (_history.isEmpty ||
        _history.last.text != message ||
        !_history.last.isUser) {
      addUserMessage(message);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/models/$_model:generateContent?key=$_apiKey',
      );

      debugPrint('[ChatService] Calling: $url');

      // Build contents array from history (skip last user msg)
      final contents = <Map<String, dynamic>>[];
      for (var i = 0; i < _history.length - 1; i++) {
        final msg = _history[i];
        contents.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text}
          ],
        });
      }

      // Add current message
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message.trim()}
        ],
      });

      final body = jsonEncode({
        'contents': contents,
        'systemInstruction': {
          'parts': [
            {'text': _systemInstruction}
          ],
        },
        'generationConfig': {
          'maxOutputTokens': 500,
          'temperature': 0.4,
        },
      });

      debugPrint('[ChatService] Request body: $body');

      final response = await _client
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint('[ChatService] Response status: ${response.statusCode}');
      debugPrint('[ChatService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Check for prompt feedback (blocked responses)
        final promptFeedback = data['promptFeedback'];
        if (promptFeedback != null) {
          debugPrint('[ChatService] Prompt feedback: $promptFeedback');
          final blockReason = promptFeedback['blockReason'];
          if (blockReason != null) {
            return 'Your message was blocked by safety filters. '
                'Please try asking about app features instead.';
          }
        }

        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0] as Map<String, dynamic>;
          debugPrint('[ChatService] Candidate keys: ${candidate.keys.toList()}');

          final content = candidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) {
              _history.add(ChatMessage(
                text: text,
                isUser: false,
                timestamp: DateTime.now(),
              ));
              return text;
            }
          }

          // Check finish reason
          final finishReason = candidate['finishReason'];
          debugPrint('[ChatService] Finish reason: $finishReason');
          if (finishReason == 'SAFETY') {
            return 'Response blocked by safety filters. '
                'Please try a different question about the app.';
          }
        }
        return 'No response received. Please try again.';
      } else if (response.statusCode == 429) {
        return 'Too many requests. Please wait a moment and try again.';
      } else {
        debugPrint(
            '[ChatService] Error ${response.statusCode}: ${response.body}');
        final errorData =
            jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMsg = errorData?['error']?['message'] as String?;
        return errorMsg ?? 'Something went wrong. Please try again later.';
      }
    } catch (e) {
      debugPrint('[ChatService] Network error: $e');
      return 'Could not connect to the server. Check your connection and try again.';
    }
  }
}
