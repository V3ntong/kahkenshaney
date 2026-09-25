import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chat_service.dart';
import '../theme/app_theme.dart';

class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 88,
      right: 20,
      child: FloatingActionButton(
        onPressed: onTap ?? () => _openChat(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.smart_toy_rounded, size: 26),
      ),
    );
  }

  void _openChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();
  bool _isTyping = false;
  bool _historyLoaded = false;

  /// Last failure, kept so the message list can show a persistent inline
  /// error with a Retry action instead of a transient snackbar.
  String? _errorText;
  String? _failedText;
  bool _errorRetryable = true;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureHistoryLoaded() async {
    if (_historyLoaded) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _chatService.loadHistory(uid);
    }
    if (mounted) setState(() => _historyLoaded = true);
  }

  Future<void> _persistHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && mounted) {
      await _chatService.saveHistory(uid);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// First name used in the empty-state greeting.
  String get _firstName {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'there';
  }

  Future<void> _send({String? retryText}) async {
    final isRetry = retryText != null;
    final text = isRetry ? retryText : _controller.text.trim();
    if (text.isEmpty) return;

    if (!isRetry) {
      _controller.clear();
      HapticFeedback.lightImpact();
    }

    await _ensureHistoryLoaded();

    if (!isRetry) {
      // On retry the failed message is already in history — don't duplicate.
      _chatService.addUserMessage(text);
    }
    setState(() {
      _isTyping = true;
      _errorText = null;
      _failedText = null;
    });
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(text);
      if (!mounted) return;
      setState(() => _isTyping = false);

      final history = _chatService.history;
      if (reply.isNotEmpty &&
          (history.isEmpty || history.last.text != reply)) {
        _chatService.addAssistantMessage(reply);
        setState(() {});
      }
      _scrollToBottom();
      await _persistHistory();
    } on ChatSendException catch (e) {
      debugPrint('[Chatbot] Send failed: ${e.code} — ${e.message}');
      if (!mounted) return;
      await _persistHistory();
      setState(() {
        _isTyping = false;
        _errorText = e.message;
        _failedText = text;
        _errorRetryable = e.retryable;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chatbot] Send error: $e');
      if (!mounted) return;
      await _persistHistory();
      setState(() {
        _isTyping = false;
        _errorText = 'Failed to get response. Please try again.';
        _failedText = text;
        _errorRetryable = true;
      });
      _scrollToBottom();
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureHistoryLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1),
          Expanded(
            child: _chatService.history.isEmpty
                ? (_errorText == null
                    ? _buildWelcome()
                    : _buildErrorOnlyState())
                : _buildMessages(),
          ),
              if (_isTyping) _buildTypingIndicator(),
              _buildInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KashTeP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'App help assistant',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _chatService.clearHistory();
              setState(() {
                _errorText = null;
                _failedText = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.textTertiary,
            tooltip: 'Clear chat',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Hello, $_firstName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "I'm KashTeP — I can help you navigate the app, explain features, and answer questions about how things work.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _QuickChip(
                  label: 'What is AI Scan?',
                  onTap: () {
                    _controller.text = 'What is AI Scan?';
                    _send();
                  },
                ),
                _QuickChip(
                  label: 'How does matching work?',
                  onTap: () {
                    _controller.text = 'How does matching work?';
                    _send();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// History is empty but the first send failed — show the error centered
  /// instead of an empty screen.
  Widget _buildErrorOnlyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: _InlineError(
          message: _errorText!,
          retryable: _errorRetryable,
          onRetry: () => _send(retryText: _failedText),
          centered: true,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'KashTeP is thinking...',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    final messages = _chatService.history;
    final showError = _errorText != null;
    final itemCount = messages.length + (showError ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final msg = messages[index];
          return _MessageBubble(
            text: msg.text,
            isUser: msg.isUser,
          );
        }
        return _InlineError(
          message: _errorText!,
          retryable: _errorRetryable,
          onRetry: () => _send(retryText: _failedText),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask KashTeP...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _controller.text.trim().isEmpty
                  ? AppColors.textTertiary.withValues(alpha: 0.3)
                  : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _send,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isUser ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
      backgroundColor: AppColors.primarySurface,
      side: const BorderSide(color: AppColors.primary, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

/// Persistent inline error row shown under the failed user message, with a
/// Retry action so the failure can be resolved from the conversation itself.
class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.retryable,
    required this.onRetry,
    this.centered = false,
  });

  final String message;
  final bool retryable;
  final VoidCallback onRetry;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.error,
              ),
            ),
          ),
          if (retryable) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );

    if (centered) return content;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: content,
      ),
    );
  }
}
