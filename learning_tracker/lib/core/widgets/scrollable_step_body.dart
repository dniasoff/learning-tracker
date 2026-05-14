import 'package:flutter/material.dart';

/// Wraps a step body in [SafeArea] + [SingleChildScrollView] with
/// keyboard-dismiss-on-drag, preventing overflow when the soft keyboard
/// is open (e.g. on a Samsung S24+ viewport).
///
/// Drop [Spacer] and [Expanded] children before wrapping — [ScrollView]
/// children must have bounded height.
class ScrollableStepBody extends StatelessWidget {
  const ScrollableStepBody({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: padding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    );
  }
}
