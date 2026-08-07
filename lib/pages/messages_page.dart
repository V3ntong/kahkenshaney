import 'package:flutter/material.dart';

import '../widgets/coming_soon_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      icon: Icons.chat_bubble_rounded,
      title: 'Messages',
      message:
          'Chats with the Lost & Found office and other users will appear here.',
    );
  }
}
