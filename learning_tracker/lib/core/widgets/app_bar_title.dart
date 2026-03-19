import 'package:flutter/material.dart';

/// AppBar title widget that auto-scales long text via [FittedBox]
/// instead of truncating with ellipsis.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle({super.key, this.text, this.child});

  /// Text to display. Ignored if [child] is provided.
  final String? text;

  /// Custom child widget. Wrapped in FittedBox for scaling.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 14),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: child ?? Text(text ?? ''),
      ),
    );
  }
}
