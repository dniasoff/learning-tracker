/// The `Disabled action` look (DESIGN.md `disabled-action`, UX-DR-36) and
/// the tutor read-only note shared by the sub-track rows and cards
/// (Story 2.9, DNI-500).
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

/// The single note on a read-only tutor sub-track surface (AC-9,
/// UX-DR-158): every sub-track write control there is visible but disabled
/// until tutor sub-track writes ship (DNI-509/DNI-510). Shown once per
/// surface, never per row.
class SubTrackTutorReadOnlyNote extends StatelessWidget {
  /// Creates the note.
  const SubTrackTutorReadOnlyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Row(
      key: const Key('subTrackTutorReadOnlyNote'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: colors.brandInkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.subTrackTutorReadOnlyNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.brandInkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
