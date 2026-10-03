/// The `Disabled action` look (DESIGN.md `disabled-action`, UX-DR-36)
/// shared by the sub-track rows (Story 2.9, DNI-500). A tutor's disabled
/// controls carry the tutoring `TutorWriteNote` instead of a read-only
/// note (Story 4.2, DNI-510: the "coming soon" note is gone).
library;

import 'package:flutter/material.dart';

/// Opacity of a disabled sub-track action (DESIGN.md: 40%).
const double subTrackDisabledOpacity = 0.4;

/// Renders [child] — a button built with a null `onPressed` — as a
/// `Disabled action`: in place at full size, 40% opacity, exposed to
/// semantics as disabled, and swallowing taps so the enclosing row's body
/// tap does not fire through it ("tapping does nothing").
class SubTrackDisabledAction extends StatelessWidget {
  /// Wraps [child].
  const SubTrackDisabledAction({super.key, required this.child});

  /// The disabled button.
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: () {},
    child: Opacity(opacity: subTrackDisabledOpacity, child: child),
  );
}
