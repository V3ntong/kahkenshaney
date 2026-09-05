import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController controller;

  /// Optional external [FocusNode] (e.g. to focus the password field after
  /// selecting a saved account). When null an internal one is managed here.
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final bool showVisibilityToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    // Only dispose nodes we created; external owners dispose their own.
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suffixIcon = widget.showVisibilityToggle
        ? IconButton(
            tooltip: _obscured ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscured
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppColors.textTertiary,
            ),
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 20, color: AppColors.textTertiary)
              : null,
          suffixIcon: suffixIcon,
          errorMaxLines: 2,
        ),
      ),
    );
  }
}
