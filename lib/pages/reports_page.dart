import 'package:flutter/material.dart';

import '../widgets/coming_soon_page.dart';

/// Reports tab - lost & found item listing (coming soon).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      icon: Icons.report_rounded,
      title: 'Reports',
      message: 'Browse, filter and manage lost & found reports here soon.',
    );
  }
}
