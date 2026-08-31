import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../data/storage/storage_service.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/item_form_fields.dart';
import '../widgets/photo_upload_field.dart';

/// Form for submitting a found item.
///
/// Fields: Category, Color, Location Found, Date Found, Storage Location,
/// Photos. Submits through [ItemRepository] and [StorageService] by default.
class SubmitFoundPage extends StatefulWidget {
  const SubmitFoundPage({
    super.key,
    this.repository,
    this.storageService,
    this.onSubmit,
  });

  final ItemRepository? repository;
  final StorageService? storageService;

  /// Overrides the default Firestore/Storage submission for tests.
  final Future<void> Function(LostFoundItem item, List<File> photos)? onSubmit;

  @override
  State<SubmitFoundPage> createState() => _SubmitFoundPageState();
}

class _SubmitFoundPageState extends State<SubmitFoundPage> {
  final _formKey = GlobalKey<FormState>();
  final _colorController = TextEditingController();
  final _locationController = TextEditingController();
  final _storageController = TextEditingController();

  String? _category;
  DateTime? _date;
  List<File> _photos = [];
  bool _submitting = false;

  @override
  void dispose() {
    _colorController.dispose();
    _locationController.dispose();
    _storageController.dispose();
    super.dispose();
  }

  String _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    } catch (_) {
      return 'anonymous';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null) return;

    setState(() => _submitting = true);
    try {
      final id = widget.onSubmit == null
          ? (widget.repository ?? ItemRepository()).newId()
          : (widget.repository?.newId() ?? '');
      final item = LostFoundItem(
        id: id,
        kind: ItemKind.found,
        title: _category ?? 'Found item',
        description: _colorController.text.trim(),
        ownerUid: _currentUid(),
        category: _category,
        location: _locationController.text.trim(),
        storageLocation: _storageController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.onSubmit != null) {
        await widget.onSubmit!(item, _photos);
      } else {
        final repository = widget.repository ?? ItemRepository();
        final storageService =
            widget.storageService ?? StorageService();
        final results = await storageService.uploadItemPhotos(
          folder: 'found',
          itemId: item.id,
          images: _photos,
        );
        final urls = results.map((r) => r.url).toList();
        final primaryResult = results.isNotEmpty ? results.first : null;
        await repository.addItem(
          item.copyWith(
            media: urls,
            imageUrl: primaryResult?.url,
            storagePath: primaryResult?.path,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Found item report submitted.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Found Item')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _buildIntroCard(context),
              const SizedBox(height: 24),
              const FormSectionLabel('ITEM DETAILS'),
              const SizedBox(height: 12),
              CategoryDropdown(
                value: _category,
                onChanged: (value) => setState(() => _category = value),
                validator: (value) =>
                    value == null ? 'Category is required.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g. Black',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
              ),
              const SizedBox(height: 24),
              const FormSectionLabel('WHEN & WHERE'),
              const SizedBox(height: 12),
              FormDateField(
                label: 'Date Found',
                date: _date,
                onSelected: (value) => setState(() => _date = value),
                lastDate: DateTime.now(),
              ),
              if (_date == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Date is required.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location Found',
                  hintText: 'e.g. Cafeteria • Ground Floor',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Location is required.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storageController,
                decoration: const InputDecoration(
                  labelText: 'Storage Location',
                  hintText: 'e.g. Lost & Found Office',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Storage location is required.'
                    : null,
              ),
              const SizedBox(height: 24),
              const FormSectionLabel('PHOTO UPLOAD'),
              const SizedBox(height: 12),
              PhotoUploadField(
                images: _photos,
                onChanged: (value) => setState(() => _photos = value),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Submit Report',
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Found something? Log the details below so we can reunite it '
              'with its owner.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
