import 'package:flutter/material.dart';

import '../data/storage/storage_service.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';

/// Image gallery that lists every image stored under the `lost/` and `found/`
/// Firebase Storage folders, kept visually separated by tabs.
class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({
    super.key,
    this.initialKind = ItemKind.lost,
    this.storageService,
  });

  /// Which tab to open on. When opened from the Lost tab this is
  /// [ItemKind.lost]; from the Found tab it is [ItemKind.found].
  final ItemKind initialKind;

  final StorageService? storageService;

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? StorageService();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialKind == ItemKind.found ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Gallery'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lost Items'),
            Tab(text: 'Found Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ImageGalleryView(
            folderName: 'lost',
            storageService: _storageService,
            emptyMessage: 'No lost items available.',
          ),
          _ImageGalleryView(
            folderName: 'found',
            storageService: _storageService,
            emptyMessage: 'No found items available.',
          ),
        ],
      ),
    );
  }
}

/// Fetches and displays the images of one Storage folder with loading,
/// empty, error and pull-to-refresh states.
class _ImageGalleryView extends StatefulWidget {
  const _ImageGalleryView({
    required this.folderName,
    required this.storageService,
    required this.emptyMessage,
  });

  final String folderName;
  final StorageService storageService;
  final String emptyMessage;

  @override
  State<_ImageGalleryView> createState() => _ImageGalleryViewState();
}

class _ImageGalleryViewState extends State<_ImageGalleryView> {
  List<String>? _urls;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final urls = await widget.storageService
          .fetchImagesFromFolder(widget.folderName);
      if (!mounted) return;
      setState(() {
        _urls = urls;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
          'ImageGallery: failed to load ${widget.folderName} images: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _CenterState(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading images...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_failed) {
      return _CenterState(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load images.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please try again.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final urls = _urls ?? const <String>[];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: urls.isEmpty ? _buildEmpty() : _buildGrid(urls),
    );
  }

  Widget _buildEmpty() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 44,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<String> urls) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: urls.length,
          itemBuilder: (context, index) => _GalleryTile(imageUrl: urls[index]),
        );
      },
    );
  }
}

/// Centered non-scrolling state (loading / error).
class _CenterState extends StatelessWidget {
  const _CenterState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: child,
      ),
    );
  }
}

/// A single square image tile with rounded corners, a loading indicator and a
/// broken-image fallback.
class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.surfaceVariant,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.surfaceVariant,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
              size: 32,
            ),
          );
        },
      ),
    );
  }
}