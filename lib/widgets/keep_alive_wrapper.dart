import 'package:flutter/material.dart';

/// Keeps a [child] tab's State alive inside a [PageView] so that scroll
/// positions, form inputs and loaded data survive tab switches.
///
/// [PageView] normally disposes off-screen children; marking the page as
/// keep-alive preserves the whole element subtree instead.
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin<KeepAliveWrapper> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
