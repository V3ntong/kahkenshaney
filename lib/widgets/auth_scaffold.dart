import 'package:flutter/material.dart';

import 'app_logo.dart';
import 'text_animations.dart';

/// Centered, responsive layout shared by all authentication screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.footer,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(child: AppLogo()),
        const SizedBox(height: 24),
        AnimatedAuthHeader(
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 32),
        ...children,
      ],
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: footer == null
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        form,
        if (footer != null) ...[
          const SizedBox(height: 24),
          Center(child: footer!),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        // No logo in auth screens — logo only on the Landing Page.
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final remaining = constraints.maxHeight - 64;
            final minHeight = remaining < 0 ? 0.0 : remaining;
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minHeight,
                  maxWidth: 440,
                ),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}
