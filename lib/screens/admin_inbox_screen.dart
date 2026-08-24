import 'package:flutter/material.dart';

import '../data/firestore/support_chat_service.dart';
import '../models/support_chat.dart';
import '../theme/app_theme.dart';
import 'admin_chat_detail_screen.dart';

/// Admin inbox — lists all user chats sorted by lastMessageAt.
///
/// Shows user name, last message preview, timestamp, and an unread
/// indicator. Tapping opens the admin chat detail for that user.
class AdminInboxScreen extends StatefulWidget {
  const AdminInboxScreen({
    super.key,
    required this.adminUid,
  });

  final String adminUid;

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  late final SupportChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = SupportChatService(adminUid: widget.adminUid);
  }

  void _openChat(SupportChat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminChatDetailScreen(
          chatId: chat.userId,
          adminUid: widget.adminUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<SupportChat>>(
        stream: _chatService.streamAllChats(),
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
                      'Could not load chats',
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

          final chats = snapshot.data ?? const <SupportChat>[];

          if (chats.isEmpty) {
            return _buildEmpty();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
              color: AppColors.cardBorder,
            ),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatTile(
                chat: chat,
                chatService: _chatService,
                onTap: () => _openChat(chat),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
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
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 36,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When users message support, their conversations will appear here.',
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

// ── Chat Tile ─────────────────────────────────────────────────────────────

class _ChatTile extends StatefulWidget {
  const _ChatTile({
    required this.chat,
    required this.chatService,
    required this.onTap,
  });

  final SupportChat chat;
  final SupportChatService chatService;
  final VoidCallback onTap;

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  String _userName = 'User';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await widget.chatService.getUserDisplayName(widget.chat.userId);
    if (!mounted) return;
    setState(() {
      _userName = name;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final hasUnread = chat.unreadByAdmin;
    final lastTime = chat.lastMessageAt;

    return ListTile(
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: hasUnread ? AppColors.primary : AppColors.surfaceVariant,
            child: Text(
              _loading ? '?' : _userName[0].toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: hasUnread ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        _loading ? 'Loading...' : _userName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: lastTime != null
          ? Text(
              _formatRelativeTime(lastTime),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread ? AppColors.primary : AppColors.textTertiary,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            )
          : null,
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}';
  }
}
