import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/firestore/support_chat_service.dart';
import '../models/support_message.dart';
import '../theme/app_theme.dart';

/// Admin chat detail screen — reuses the same message-bubble UI as the
/// user screen, but sends with `isAdmin: true`.
///
/// The admin can see and reply to a specific user's thread.
class AdminChatDetailScreen extends StatefulWidget {
  const AdminChatDetailScreen({
    super.key,
    required this.chatId,
    required this.adminUid,
  });

  /// The user's UID (chat document ID).
  final String chatId;
  final String adminUid;

  @override
  State<AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  SupportChatService? _chatService;
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  final _focusNode = FocusNode();
  String _userName = 'User';
  bool _loadingName = true;
  bool _ready = false;
  bool _readMarked = false;
  String? _resolvedAdminUid;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
    _resolveAdminAndInit();
  }

  /// Looks up the real admin UID from Firestore, then initializes the
  /// chat service and ensures the admin is in the participants array.
  Future<void> _resolveAdminAndInit() async {
    // Look up the real admin UID from the users collection.
    final realUid = await SupportChatService.lookupAdminUid(null);
    final adminUid = realUid ?? widget.adminUid;

    if (!mounted) return;

    final service = SupportChatService(adminUid: adminUid);

    // Ensure the admin is in the participants array (fixes orphaned chats).
    await service.ensureParticipant(widget.chatId, adminUid);

    if (!mounted) return;
    setState(() {
      _resolvedAdminUid = adminUid;
      _chatService = service;
      _ready = true;
    });
    _loadUserName();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await _chatService?.getUserDisplayName(widget.chatId) ?? 'User';
    if (!mounted) return;
    setState(() {
      _userName = name;
      _loadingName = false;
    });
  }

  Future<void> _markAsRead() async {
    await _chatService?.markReadByAdmin(widget.chatId);
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    if (!_ready || _chatService == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    _controller.clear();
    _focusNode.requestFocus();

    final adminUid = _resolvedAdminUid ?? widget.adminUid;

    // Fire-and-forget: let the stream display the message.
    _chatService!.sendMessage(
      chatId: widget.chatId,
      senderId: adminUid,
      text: text,
      isAdmin: true,
      imageUrl: imageUrl,
    ).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    });

    // Scroll to bottom after sending.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    try {
      final file = File(picked.path);
      final fileName = 'chat_${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('chat_images/$fileName');
      await ref.putFile(
        file,
        SettableMetadata(
          customMetadata: {'metadataUploaderId': widget.adminUid},
        ),
      );
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      _sendMessage(imageUrl: url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_loadingName ? 'Chat...' : 'Chat with $_userName'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.infoSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 14, color: AppColors.info),
                const SizedBox(width: 4),
                Text(
                  _loadingName ? '...' : _userName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _chatService == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
        children: [
          // ── Messages list ────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: _chatService!.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.error),
                          const SizedBox(height: 16),
                          const Text(
                            'Could not load messages',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? const <SupportMessage>[];

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                // Mark as read once messages are visible (not on init).
                if (!_readMarked) {
                  _readMarked = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == (_resolvedAdminUid ?? widget.adminUid);
                    return _AdminMessageBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ────────────────────────────────────────
          _AdminInputBar(
            controller: _controller,
            focusNode: _focusNode,
            onSend: _sendMessage,
            onImagePick: _pickAndSendImage,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages with $_userName yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a message to start the conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble (Admin version) ────────────────────────────────────────

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({
    required this.message,
    required this.isMe,
  });

  final SupportMessage message;
  final bool isMe;

  void _openFullScreen(BuildContext context, String imageUrl) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _FullScreenImage(imageUrl: imageUrl),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.info : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              GestureDetector(
                onLongPress: () => _openFullScreen(context, message.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    message.imageUrl!,
                    width: 200,
                    height: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 200,
                        height: 150,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 150,
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.15)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 36,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            if (hasImage && message.text.isNotEmpty) const SizedBox(height: 6),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final h = time.hour;
    final m = time.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }
}

// ── Full-Screen Image Viewer (Admin) ─────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.white54),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input Bar (Admin version) ─────────────────────────────────────────────

class _AdminInputBar extends StatelessWidget {
  const _AdminInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onImagePick,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback? onImagePick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (onImagePick != null)
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 22),
                color: AppColors.textSecondary,
                onPressed: onImagePick,
                tooltip: 'Send image',
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Reply to user...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
