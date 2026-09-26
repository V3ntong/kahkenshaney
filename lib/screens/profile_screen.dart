import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lost_found_item.dart';
import '../providers/profile_provider.dart';
import '../screens/item_detail_screen.dart';
import '../screens/upload_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/item_grid_card.dart';
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
      body: ListView(
        padding: EdgeInsets.zero,
        children: const [
          ProfileHeader(),
          Divider(height: 1, color: AppColors.border),
          _OwnItemsSection(title: 'Found', kind: ItemKind.found),
          _OwnItemsSection(title: 'Lost', kind: ItemKind.lost),
          Divider(height: 1, color: AppColors.border),
          PostGrid(),
        ],
      ),
    );
  }
}

/// Horizontally scrolling "Found" / "Lost" lists of the items the signed-in
/// user personally submitted.
class _OwnItemsSection extends StatelessWidget {
  const _OwnItemsSection({required this.title, required this.kind});

  final String title;
  final ItemKind kind;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final items = provider.ownItems
            .where((i) => i.kind == kind)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return SizedBox(
                    width: 150,
                    child: ItemGridCard(
                      item: item,
                      heroTagPrefix: 'profile_${kind.name}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(
                              item: item,
                              heroTagPrefix: 'profile_${kind.name}',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
