import 'package:flutter/material.dart';

/// Animated tab host that switches between [pages] with a smooth Material
/// motion transition (~300ms).
///
/// Each page is a [PageView] item animated by a shared [PageController]:
/// * horizontal slide (driven by the viewport),
/// * fade + subtle scale + vertical drift (driven by [ListenableBuilder]).
///
/// Swipe is disabled so tab changes only happen through the bottom
/// navigation, keeping transitions predictable. State is preserved because
/// pages are wrapped in [KeepAliveWrapper] upstream.
class TabSwitcher extends StatelessWidget {
  const TabSwitcher({
    super.key,
    required this.controller,
    required this.pages,
    this.onPageChanged,
  });

  final PageController controller;
  final List<Widget> pages;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: onPageChanged,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return _TransitionPage(
          controller: controller,
          index: index,
          child: pages[index],
        );
      },
    );
  }
}

class _TransitionPage extends StatelessWidget {
  const _TransitionPage({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      child: child,
      builder: (context, child) {
        final position = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final distance = (position - index).abs().clamp(0.0, 1.0);
        final opacity = 1.0 - distance;
        final translateY = 14.0 * distance;
        final scale = 1.0 - 0.05 * distance;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
