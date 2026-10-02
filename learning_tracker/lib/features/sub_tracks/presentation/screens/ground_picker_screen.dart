/// The phone ground-picker route (Story 2.7 / DNI-498 AC-2, screens.md
/// #08): the picker full screen for one sub-track.
///
/// `/sub-tracks/:subTrackId/ground` is guarded by the shared
/// `ParentSessionGuard` (a child without the parent PIN, a tutored session
/// or a deep link is refused before anything loads, AC-8), and the picker
/// itself re-checks the session, the calendar-program block (AC-7) and the
/// sub-track, so the route never shows an editable control it should not.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';

/// The picker for sub-track [subTrackId], full screen.
@RoutePage()
class GroundPickerScreen extends StatelessWidget {
  /// Creates the screen.
  const GroundPickerScreen({
    super.key,
    @PathParam('subTrackId') required this.subTrackId,
  });

  /// The sub-track receiving ground.
  final String subTrackId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: GroundPickerPane(
        subTrackId: subTrackId,
        onClose: () => context.router.maybePop(),
      ),
    ),
  );
}
