import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../data/firestore/notification_service.dart';
import '../data/storage/storage_service.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/centered_success_overlay.dart';
import '../widgets/fade_slide_in.dart';
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
        reportedBy: _currentUid(),
        category: _category,
        location: _locationController.text.trim(),
        storageLocation: _storageController.text.trim(),
        eventDate: _date,
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
          userId: _currentUid(),
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

        // Notify admin of new report
        await NotificationService().notifyAdminNewReport(
          item: item.copyWith(
            media: urls,
            imageUrl: primaryResult?.url,
            storagePath: primaryResult?.path,
          ),
        );
      }

      if (!mounted) return;
      CenteredSuccessOverlay.show(
        context,
        message: 'Found item report submitted',
      );
      // Delay navigation slightly so the overlay is visible before popping.
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            children: _buildFormChildren(context),
          ),
        ),
      ),
    );
  }

  /// Form fields wrapped in a fadeInDown cascade.
  ///
  /// Every returned slot is present on every build (the date hint is always a
  /// widget, it just renders empty when a date has been picked), so child
  /// indices — and therefore each field's [FadeSlideInWidget] state — never
  /// shift. The entrance therefore runs once on genuine page entry and never
  /// replays on field validation, date selection, or photo changes.
  List<Widget> _buildFormChildren(BuildContext context) {
    final wrapped = <Widget>[];
    Widget add(Widget child) {
      final w = FadeSlideInWidget(
        delay: FadeSlideInWidget.staggerDelay(
          wrapped.length,
          perItemMs: 45,
          maxSpreadMs: 360,
        ),
        duration: const Duration(milliseconds: 320),
        offset: 18,
        child: child,
      );
      wrapped.add(w);
      return w;
    }

    return [
      add(_buildIntroCard(context)),
      const SizedBox(height: 24),
      add(const FormSectionLabel('ITEM DETAILS')),
      const SizedBox(height: 12),
      add(
        CategoryDropdown(
          value: _category,
          onChanged: (value) => setState(() => _category = value),
          validator: (value) => value == null ? 'Category is required.' : null,
        ),
      ),
      const SizedBox(height: 16),
      add(
        TextFormField(
          controller: _colorController,
          decoration: const InputDecoration(
            labelText: 'Color',
            hintText: 'e.g. Black',
            prefixIcon: Icon(Icons.palette_outlined),
          ),
        ),
      ),
      const SizedBox(height: 24),
      add(const FormSectionLabel('WHEN & WHERE')),
      const SizedBox(height: 12),
      add(
        FormDateField(
          label: 'Date Found',
          date: _date,
          onSelected: (value) => setState(() => _date = value),
          lastDate: DateTime.now(),
        ),
      ),
      // Always present so the form's child count (and thus the entrance
      // animation states) stays stable — it only shows text when needed.
      add(_DateRequiredHint(visible: _date == null)),
      const SizedBox(height: 16),
      add(
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
      ),
      const SizedBox(height: 16),
      add(
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
      ),
      const SizedBox(height: 24),
      add(const FormSectionLabel('PHOTO UPLOAD')),
      const SizedBox(height: 12),
      add(
        PhotoUploadField(
          images: _photos,
          onChanged: (value) => setState(() => _photos = value),
        ),
      ),
      const SizedBox(height: 32),
      add(
        AppButton(
          label: 'Submit Report',
          icon: Icons.send_rounded,
          loading: _submitting,
          onPressed: _submit,
        ),
      ),
    ];
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

/// Small "date required" hint that is always mounted (see the parent's
/// comment on why) and simply renders nothing once a date is chosen.
class _DateRequiredHint extends StatelessWidget {
  const _DateRequiredHint({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(top: 6, left: 12),
      child: Text(
        'Date is required.',
        style: TextStyle(fontSize: 12, color: AppColors.error),
      ),
    );
  }
}
