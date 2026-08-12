// active_tutored_profile_provider — WS3.3c / WS3.3d
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
//   • Permission-gated UI — to determine available actions (via activeTutorPermissionsProvider)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_tutored_profile_provider.g.dart';

/// Holds the current [TutoredProfileSelection] while the tutor is viewing a
/// talmid's profile context. Cleared when the tutor exits the talmid view.
///
/// `keepAlive: true` so the selection persists across route changes while the
/// tutor is inside the talmid's profile.
@Riverpod(keepAlive: true)
class ActiveTutoredProfileSelection extends _$ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() {
    // Account-switch reset is handled at the AppShell level via ref.listen
    // on authStateProvider — see app_shell.dart _AccountSwitchObserver.
    // Keeping the auth chain OUT of this build() means widget tests that
    // don't mount AppShell never materialise FirebaseAuth.instance.
    return null;
  }

  /// Enter a talmid's context after the TutorPinEntryGate passes.
  void enter(TutoredProfileSelection selection) => state = selection;

  /// Exit the talmid context (return to own profile).
  ///
  void exit() {
    state = null;
  }
}

/// Convenience provider: exposes the [TutorPermissions] for the currently
/// active tutored-profile context, or `null` when not in a tutored session.
///
/// UI affordances (edit tracks, rewards, goals, study days) should gate on
/// the relevant `canEdit*` field from this provider.
///
/// Example:
/// ```dart
/// final perms = ref.watch(activeTutorPermissionsProvider);
/// if (perms == null || perms.canEditRewards) {
///   // show the Rewards tile (owner always sees it; tutor sees it iff allowed)
/// }
/// ```
final activeTutorPermissionsProvider = Provider<TutorPermissions?>((ref) {
  final selection = ref.watch(activeTutoredProfileSelectionProvider);
  return selection?.permissions;
}, name: 'activeTutorPermissionsProvider');
