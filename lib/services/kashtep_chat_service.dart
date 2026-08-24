import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Chat message model for the KashTeP chatbot.
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

/// KashTeP chatbot service — direct Gemini API integration (free tier).
///
/// SECURITY NOTE: The API key is exposed in the client binary.
/// Acceptable for testing, prototyping, and school projects.
/// For production, migrate to a backend proxy.
class KashtepChatService {
  KashtepChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String _model = 'gemini-3.6-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static const String _systemInstruction = '''
You are KashTeP, the official AI assistant for KAH KEN SHA NEY — an AI and ML-powered application that turns your lost into found.

Your ONLY purpose is to help users with the app. You must:
- Explain how to report lost items
- Guide users through submitting found items
- Explain the AI matching feature
- Help with navigation and app features
- Answer questions about authentication and profiles

If a user asks about anything UNRELATED to the app, politely decline and redirect them back to app features.

App Features:
- Report Lost Items: name, category, color, date, location, photos
- Submit Found Items: category, color, location, storage location, photos
- AI Matching: matches lost and found items using descriptions and photos
- AI Camera Scanner: point camera at an item to identify it
- User Auth: email/password + OTP verification
- Real-time Updates: live Firestore streams
- Profile Management: view profile, change password
- Messages: chat with finders (coming soon)

Developer Information:

KAH KEN SHA NEY was developed by:
- Melvin Maquilan
- Cristian Jim Pogoy
- Axl Moraleja
- Aldrian Dajes

They are 3rd-year BSCS (Bachelor of Science in Computer Science) students at SMCTI.

Developer questions must be answered briefly and completely. When asked who developed, created, made, built, or is behind KAH KEN SHA NEY or this assistant, respond with exactly the verified developer information below. Do not omit any developer names. Do not start with unnecessary phrases such as "I am the Official AI assistant", "I am an AI-powered assistant", "Hello!", or "Let me tell you". Do not use Markdown bold or bullet lists. Use plain text only:

KAH KEN SHA NEY was developed by Melvin Maquilan, Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes. They are 3rd-year BSCS students at SMCTI.

Do not invent additional information about the developers.
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

  /// Send a message and get a response from Gemini.
  Future<String> sendMessage(String message) async {
    if (message.trim().isEmpty) return '';

    if (_apiKey.isEmpty) {
      debugPrint('[Kashtep] API key is empty — check .env file');
      return 'API key not configured. Please check your .env file.';
    }

    // Add user message if not already added
    if (_history.isEmpty ||
        _history.last.text != message ||
        !_history.last.isUser) {
      addUserMessage(message);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/models/$_model:generateContent?key=$_apiKey',
      );

      // Build contents from conversation history
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
          'maxOutputTokens': 2048,
          'temperature': 0.4,
        },
      });

      debugPrint('[Kashtep] Sending request to Gemini API...');

      final response = await _client
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint('[Kashtep] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Check for blocked prompts
        final promptFeedback = data['promptFeedback'];
        if (promptFeedback != null) {
          final blockReason = promptFeedback['blockReason'];
          if (blockReason != null) {
            debugPrint('[Kashtep] Blocked: $blockReason');
            return 'Your message was blocked by safety filters. '
                'Please try asking about app features instead.';
          }
        }

        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0] as Map<String, dynamic>;
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
              debugPrint('[Kashtep] Response: ${text.substring(0, text.length.clamp(0, 100))}...');
              return text;
            }
          }

          final finishReason = candidate['finishReason'];
          if (finishReason == 'SAFETY') {
            return 'Response blocked by safety filters. '
                'Please try a different question about the app.';
          }
        }

        return 'No response received. Please try again.';
      } else if (response.statusCode == 429) {
        return 'Too many requests. Please wait a moment and try again.';
      } else {
        debugPrint('[Kashtep] Error ${response.statusCode}: ${response.body}');
        final errorData =
            jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMsg = errorData?['error']?['message'] as String?;
        return errorMsg ?? 'Something went wrong. Please try again later.';
      }
    } catch (e) {
      debugPrint('[Kashtep] Network error: $e');
      return 'Could not connect to the server. Check your connection and try again.';
    }
  }
}
