import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const List<String> itemCategories = [
  'Electronics',
  'Documents',
  'Keys',
  'Wallet',
  'Accessories',
  'Clothing',
  'Books',
  'Bags',
  'ID & Cards',
  'Other',
];

/// Small uppercase section caption used between form fields.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// Dropdown that picks one of the shared [itemCategories].
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [
        for (final category in itemCategories)
          DropdownMenuItem(value: category, child: Text(category)),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// A tappable field that opens the platform date picker.
class FormDateField extends StatelessWidget {
  const FormDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onSelected,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date == null ? label : _formatDate(date!),
                style: TextStyle(
                  fontSize: 15,
                  color: date == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontWeight: date == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
