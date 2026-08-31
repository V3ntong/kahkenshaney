import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../screens/upload_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/post_grid.dart';
import '../widgets/profile_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Consumer<ProfileProvider>(
          builder: (_, provider, _) {
            final name = provider.user?.displayName;
            return Text(
              name != null && name.isNotEmpty ? name : 'Profile',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
              );
            },
            icon: const Icon(
              Icons.add_box_outlined,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: const Column(
        children: [
          ProfileHeader(),
          Divider(height: 1, color: AppColors.border),
          Expanded(child: PostGrid()),
        ],
      ),
    );
  }
}
