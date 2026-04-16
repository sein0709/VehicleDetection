import 'package:flutter/material.dart';

/// Returns true when the window is wide enough for a desktop-style layout.
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 840;

/// Constrains [child] to a comfortable reading width on wide screens.
/// On narrow screens the child fills the available width.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (!wide) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A two-column layout for desktop: master list on the left, detail on the right.
/// Falls back to showing only [master] on narrow screens.
class MasterDetailLayout extends StatelessWidget {
  const MasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
    this.masterWidth = 360,
  });

  final Widget master;
  final Widget? detail;
  final double masterWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    if (!wide || detail == null) return master;

    return Row(
      children: [
        SizedBox(width: masterWidth, child: master),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: detail!),
      ],
    );
  }
}
