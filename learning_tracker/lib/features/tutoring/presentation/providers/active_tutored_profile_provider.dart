// active_tutored_profile_provider — WS3.3c
//
// Holds the active TutoredProfileSelection when a tutor has entered a
// talmid's profile context (after passing the TutorPinEntryGate).
//
// null  → no tutored-profile context active (normal own-profile mode).
// non-null → tutor is viewing a talmid; the value carries the grant + perms.
//
// Used by:
//   • router_provider.dart — to resolve PinScope.tutor() vs PinScope.parent()
//   • app_shell.dart — to show the "acting as tutor for X" indicator
//   • Permission-gated UI — to determine available actions

import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_tutored_profile_provider.g.dart';

/// Holds the current [TutoredProfileSelection] while the tutor is viewing a
/// talmid's profile context. Cleared when the tutor exits the talmid view.
///
/// `keepAlive: true` so the selection persists across route changes while the
/// tutor is inside the talmid's profile.
@Riverpod(keepAlive: true)
class ActiveTutoredProfileSelection
    extends _$ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;

  /// Enter a talmid's context after the TutorPinEntryGate passes.
  void enter(TutoredProfileSelection selection) => state = selection;

  /// Exit the talmid context (return to own profile).
  void exit() => state = null;
}
