import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

/// Grid picker that lets the user select photos for an item report.
///
/// Shows thumbnails for already-picked images with a tappable add tile.
/// Picking is injected so tests can replace the platform camera/gallery.
class PhotoUploadField extends StatelessWidget {
  const PhotoUploadField({
    super.key,
    required this.images,
    required this.onChanged,
    this.pickImage,
    this.maxPhotos = 5,
  });

  final List<File> images;
  final ValueChanged<List<File>> onChanged;

  /// Custom image picker for tests; defaults to the camera/gallery picker.
  final Future<List<File>> Function()? pickImage;

  final int maxPhotos;

  Future<List<File>> _defaultPicker() async {
    final picker = ImagePicker();
    final results = await picker.pickMultiImage(imageQuality: 85);
    return results.map((e) => File(e.path)).toList();
  }

  void _addPhotos() async {
    final picked = await (pickImage ?? _defaultPicker)();
    if (picked.isEmpty) return;
    final merged = [...images, ...picked].take(maxPhotos).toList();
    onChanged(merged);
  }

  void _removeAt(int index) {
    onChanged([...images]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < images.length; i++) _Thumb(images[i], onRemove: () => _removeAt(i)),
            if (images.length < maxPhotos)
              _AddTile(
                onTap: _addPhotos,
                remaining: maxPhotos - images.length,
              ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.file, {required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.remaining});

  final VoidCallback onTap;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              'Add\n(up to $remaining)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
