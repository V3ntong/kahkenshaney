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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
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
  String? _photoUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final preview =
        await widget.chatService.getUserPreview(widget.chat.userId);
    if (!mounted) return;
    setState(() {
      _userName = preview.displayName;
      _photoUrl = preview.photoUrl;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final hasUnread = chat.unreadByAdmin;
    final unreadCount = chat.unreadByAdminCount;
    final lastTime = chat.lastMessageAt;
    final preview = chat.lastMessage.isNotEmpty
        ? chat.lastMessage
        : 'No messages yet';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: hasUnread
            ? AppColors.primarySurface.withValues(alpha: 0.75)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(hasUnread, unreadCount),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasUnread) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              _loading ? 'Loading…' : _userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (lastTime != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatTimestamp(lastTime),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: hasUnread
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                                fontWeight:
                                    hasUnread ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.3,
                                color: hasUnread
                                    ? AppColors.textSecondary
                                    : AppColors.textTertiary,
                                fontWeight:
                                    hasUnread ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool hasUnread, int unreadCount) {
    final initial = _loading || _userName.isEmpty
        ? '?'
        : _userName[0].toUpperCase();
    final photoUrl = _photoUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasUnread ? AppColors.primary : AppColors.surfaceVariant,
            border: Border.all(color: AppColors.surface, width: 2),
          ),
          child: ClipOval(
            child: photoUrl != null
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: hasUnread
                                ? Colors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) =>
                        _initialLetter(initial, hasUnread),
                  )
                : _initialLetter(initial, hasUnread),
          ),
        ),
        if (hasUnread && unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initialLetter(String initial, bool hasUnread) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: hasUnread ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Messaging-app timestamp convention:
  /// Now → `12m` → `3h` → `2d` → `Jan 5` → `Jan 5, 2025`.
  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && now.day == time.day) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final stamp = '${months[time.month - 1]} ${time.day}';
    return time.year == now.year ? stamp : '$stamp, ${time.year}';
  }
}
