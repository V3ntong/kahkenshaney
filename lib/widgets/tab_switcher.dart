import 'package:flutter/material.dart';

/// Animated tab host that switches between [pages] with a smooth Material
/// motion transition (~300ms).
///
/// Each page is a [PageView] item driven by a shared [PageController]:
/// * **Directional horizontal slide** — pages slide in from the side they're
///   coming from (left-to-right when going backwards, right-to-left going
///   forwards) so the motion always feels spatially correct.
/// * **Fade** — incoming page fades in while outgoing fades out.
/// * **Subtle scale** — incoming page scales from 0.96 → 1.0 for depth.
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
        return _DirectionalTransition(
          controller: controller,
          index: index,
          child: pages[index],
        );
      },
    );
  }
}

/// Combines directional slide, fade, and scale into a single smooth transition
/// driven by the [PageController] position.
///
/// The slide direction flips automatically: when the user taps a tab to the
/// right the incoming page slides in from the right; tapping left slides in
/// from the left. The current page offset determines opacity and scale.
class _DirectionalTransition extends StatelessWidget {
  const _DirectionalTransition({
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
        final page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();

        final distance = (page - index).clamp(-1.0, 1.0);
        final absDistance = distance.abs();

        // ── Opacity: 1.0 when on-screen, fades to 0.0 when fully off ──
        final opacity = 1.0 - absDistance;

        // ── Slide: positive distance → slide left, negative → slide right ──
        // 80px max offset keeps the motion subtle but visible.
        final slideX = 80.0 * distance;

        // ── Scale: incoming page starts at 0.96, outgoing shrinks to 0.96 ──
        final scale = 1.0 - 0.04 * absDistance;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(slideX, 0),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
