import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
/// SECURITY NOTE: The API key is bundled with the client binary. This is
/// acceptable only for testing/prototyping/school projects. For production,
/// route requests through a backend (e.g. the existing `kashtep` Cloud
/// Function) so the key stays server-side.
class ChatService {
  ChatService({
    this._client,
    this.timeout = const Duration(seconds: 30),
  });

  /// Optional injected client (used by tests). When null, a fresh client is
  /// created for each request and closed afterwards. Reused keep-alive
  /// connections can go stale on flaky mobile networks and hang the request,
  /// which is the classic cause of "first message works, later ones timeout".
  final http.Client? _client;

  /// How long to wait for a Gemini response before giving up.
  final Duration timeout;

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String _model = 'gemini-3.6-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  static const String _systemInstruction = '''
You are the official AI assistant for KAH KEN SHA NEY — an AI-powered Lost & Found app.

Be concise and helpful. Answer in 2-3 sentences max unless more detail is needed. Focus on app features and functionality.

App Features:
- Report Lost/Found Items with details like name, category, color, date, location, and photos.
- AI Matching: matches lost and found items automatically.
- AI Camera Scanner: identify items by pointing your camera.
- User Authentication: secure email/password login with OTP.
- Real-time Updates: item lists update in real-time.
- Profile Management: view profile and change password.
- Messages: chat with finders and the Lost & Found office.

Developer Information:
KAH KEN SHA NEY was developed by Melvin Maquilan, Cristian Jim Pogoy, Axl Moraleja, and Aldrian Dajes. They are 3rd-year BSCS students at SMCTI.

Do not invent information beyond the app features listed above.
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

  /// Add assistant response to history (for UI display).
  void addAssistantMessage(String message) {
    _history.add(ChatMessage(
      text: message,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';

    debugPrint('[ChatService] API key configured: ${_apiKey.isNotEmpty}');

    if (_apiKey.isEmpty) {
      debugPrint('[ChatService] GEMINI_API_KEY is missing from .env');
      return 'The AI assistant is not configured. Please check the app configuration.';
    }

    // Add the user message to history if it isn't already the last message.
    if (_history.isEmpty ||
        _history.last.text != trimmed ||
        !_history.last.isUser) {
      addUserMessage(trimmed);
    }

    final client = _client ?? http.Client();

    try {
      // The API key is placed in the query string by the Gemini API. This URL
      // is deliberately never logged because it would expose the key.
      final url = Uri.parse(
        '$_baseUrl/models/$_model:generateContent?key=$_apiKey',
      );

      debugPrint('[ChatService] Sending Gemini request...');
      debugPrint('[ChatService] Conversation messages: ${_history.length}');

      final contents = _buildContents(trimmed);

      final body = jsonEncode({
        'contents': contents,
        'systemInstruction': {
          'parts': [
            {'text': _systemInstruction}
          ],
        },
        'generationConfig': {
          'maxOutputTokens': 1024,
          'temperature': 0.3,
          'topP': 0.8,
          'topK': 40,
        },
      });

      final response = await client
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);

      debugPrint('[ChatService] Response status: ${response.statusCode}');

      return _handleResponse(response);
    } on TimeoutException {
      debugPrint('[ChatService] Timeout while waiting for Gemini');
      return 'The AI assistant is taking too long to respond. Please try again.';
    } on SocketException catch (e) {
      debugPrint('[ChatService] Network socket error: ${e.message}');
      return 'Unable to connect to the AI assistant. '
          'Please check your internet connection and try again.';
    } on http.ClientException catch (e) {
      debugPrint('[ChatService] HTTP client error: ${e.message}');
      return 'Unable to connect to the AI assistant. '
          'Please check your internet connection and try again.';
    } catch (e) {
      debugPrint('[ChatService] Unexpected error: $e');
      return 'The AI assistant could not generate a response. Please try again.';
    } finally {
      // A fresh client is used per request so stale keep-alive sockets do not
      // cause later requests to hang. Injected clients are owned by the caller.
      if (_client == null) {
        client.close();
      }
    }
  }

  /// Converts the stored conversation into Gemini `contents`, guaranteeing an
  /// alternating `user`/`model` pattern and that the current message appears
  /// exactly once. Limits history to last 10 messages for faster responses.
  List<Map<String, dynamic>> _buildContents(String trimmed) {
    final contents = <Map<String, dynamic>>[];

    // Limit history to last 10 messages for faster API responses
    final startIdx = _history.length > 10 ? _history.length - 10 : 0;
    final recentHistory = _history.sublist(startIdx);

    for (final msg in recentHistory) {
      final text = msg.text.trim();
      if (text.isEmpty) continue;
      final role = msg.isUser ? 'user' : 'model';

      final last = contents.isNotEmpty ? contents.last : null;
      if (last != null && last['role'] == role) {
        // Merge consecutive same-role turns so the API never receives
        // user,user / model,model sequences.
        final lastText =
            ((last['parts'] as List).first as Map<String, dynamic>)['text']
                as String;
        last['parts'] = [
          {'text': '$lastText\n$text'},
        ];
      } else {
        contents.add({
          'role': role,
          'parts': [
            {'text': text},
          ],
        });
      }
    }

    // Ensure the latest user message is the final turn.
    final last = contents.isNotEmpty ? contents.last : null;
    final lastText = last == null
        ? ''
        : ((last['parts'] as List).first as Map<String, dynamic>)['text']
            as String;
    if (last == null || last['role'] != 'user' || lastText != trimmed) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': trimmed},
        ],
      });
    }

    return contents;
  }

  String _handleResponse(http.Response response) {
    final status = response.statusCode;

    if (status == 200) {
      return _parseSuccess(response.body);
    }

    switch (status) {
      case 400:
        debugPrint(
            '[ChatService] Gemini API returned HTTP 400 (invalid request)');
        return 'The AI assistant could not understand that message. '
            'Please try rephrasing.';
      case 401:
      case 403:
        debugPrint(
            '[ChatService] Gemini API returned HTTP $status (auth/config)');
        return 'The AI assistant is not configured correctly. '
            'Please contact support.';
      case 404:
        debugPrint(
            '[ChatService] Gemini API returned HTTP 404 (model not found)');
        return 'The AI assistant is temporarily unavailable. '
            'Please try again later.';
      case 429:
        debugPrint('[ChatService] Gemini API returned HTTP 429 (rate limit)');
        return 'The AI assistant is temporarily busy. Please try again shortly.';
      case 500:
      case 502:
      case 503:
      case 504:
        debugPrint(
            '[ChatService] Gemini API returned HTTP $status (server error)');
        return 'The AI assistant is temporarily unavailable. '
            'Please try again later.';
      default:
        debugPrint('[ChatService] Gemini API returned HTTP $status');
        return 'The AI assistant returned an unexpected response. '
            'Please try again.';
    }
  }

  /// Safely extracts the reply text from a Gemini `generateContent` response.
  String _parseSuccess(String rawBody) {
    Object? decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException catch (e) {
      debugPrint('[ChatService] Invalid JSON in response: $e');
      return 'The AI assistant returned an unexpected response. Please try again.';
    }

    if (decoded is! Map<String, dynamic>) {
      debugPrint('[ChatService] Response was not a JSON object');
      return 'The AI assistant returned an unexpected response. Please try again.';
    }

    final promptFeedback = decoded['promptFeedback'];
    if (promptFeedback is Map<String, dynamic>) {
      final blockReason = promptFeedback['blockReason'];
      if (blockReason is String && blockReason.isNotEmpty) {
        debugPrint('[ChatService] Prompt blocked: $blockReason');
        return 'Your message was blocked by safety filters. '
            'Please try asking about app features instead.';
      }
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      debugPrint('[ChatService] No candidates in response');
      return 'The AI assistant returned an unexpected response. Please try again.';
    }

    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      debugPrint('[ChatService] Unexpected candidate shape');
      return 'The AI assistant returned an unexpected response. Please try again.';
    }

    final finishReason = candidate['finishReason'];
    final content = candidate['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;

    if (parts is List && parts.isNotEmpty) {
      final part = parts.first;
      final text = part is Map<String, dynamic> ? part['text'] : null;
      if (text is String && text.trim().isNotEmpty) {
        final reply = text.trim();
        _history.add(ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        debugPrint('[ChatService] Gemini response parsed successfully');
        return reply;
      }
    }

    if (finishReason == 'SAFETY' || finishReason == 'BLOCKED') {
      debugPrint('[ChatService] Response blocked: $finishReason');
      return 'Your message was blocked by safety filters. '
          'Please try asking about app features instead.';
    }

    debugPrint('[ChatService] Empty response. finishReason=$finishReason');
    return 'The AI assistant returned an unexpected response. Please try again.';
  }
}
